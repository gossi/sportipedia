import { existsSync, mkdirSync, readFileSync, rmSync, statSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { toId } from 'storybook/internal/csf';

const HERE = path.dirname(fileURLToPath(import.meta.url));

/** mirrors TypeDoc's `ReflectionKind` numeric flags */
const KIND = {
  Project: 1,
  Module: 2,
  Enum: 8,
  Variable: 32,
  Function: 64,
  Class: 128,
  Interface: 256,
  TypeAlias: 2_097_152,
  Reference: 4_194_304
};

const KIND_NAME = {
  [KIND.Module]: 'module',
  [KIND.Enum]: 'enum',
  [KIND.Variable]: 'variable',
  [KIND.Function]: 'function',
  [KIND.Class]: 'class',
  [KIND.Interface]: 'interface',
  [KIND.TypeAlias]: 'type-alias'
};

const MARKDOWN_FOLDER = {
  [KIND.Interface]: 'interfaces',
  [KIND.Function]: 'functions',
  [KIND.Variable]: 'variables',
  [KIND.Class]: 'classes',
  [KIND.Enum]: 'enumerations',
  [KIND.TypeAlias]: 'type-aliases'
};

const KIND_FOLDER = Object.fromEntries(
  Object.entries(MARKDOWN_FOLDER).map(([kind, folder]) => [folder, KIND_NAME[+kind]])
);

/** folder and tag of the generated pages listing a package entry point's re-exported symbols */
const ENTRY_POINT_FOLDER = 'entry-point';

/** every typedoc markdown page is indexed as a docs entry named `Docs` */
const DOCS_NAME = 'Docs';

/** Tag.UNATTACHED_MDX — makes the docs page render the compiled MDX as-is, like a plain .mdx page */
const MDX_TAG = 'unattached-mdx';

function categoryOf(reflection) {
  const comment = reflection.comment ?? reflection.signatures?.[0]?.comment;
  const tag = comment?.blockTags?.find((blockTag) => blockTag.tag === '@category');

  return tag
    ? tag.content
        .map((part) => part.text)
        .join('')
        .trim()
    : '';
}

function titleCase(value) {
  return value
    .split(/[\s_-]+/)
    .filter(Boolean)
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ');
}

function slugOf(value) {
  return value.toLowerCase().replaceAll(/[^a-z0-9]+/gu, '-');
}

function segment(segments, value) {
  if (!value || segments.at(-1) === value) {
    return segments;
  }

  segments.push(value);

  return segments;
}

/** docs entry id for a page — every typedoc page renders as a `Docs` entry */
function docsIdOf(meta) {
  return toId(meta.title, DOCS_NAME);
}

/**
 * Normalize a source/component path to the app-relative tail ("src/..."), undoing the
 * `.gts` -> `.gts.ts` shim typedoc-plugin-ember generates for template-only components.
 */
function sourceTail(filePath) {
  if (!filePath) {
    return;
  }

  const normalized = filePath.replaceAll('\\', '/');
  const index = normalized.lastIndexOf('/src/');
  const tail = index === -1 ? normalized : normalized.slice(index + 1);

  return tail.endsWith('.gts.ts') ? tail.slice(0, -3) : tail;
}

/** meta + output path of the markdown page rendered for a reflection, if it gets one */
function pageOf(model) {
  if (model.kind === KIND.Module) {
    const pkg = model.parent;

    // package index page (e.g. `equipment/README.md`)
    if (!pkg || pkg.kind === KIND.Project) {
      const name = titleCase(model.name);

      return {
        title: name,
        name,
        tags: ['kind-module', 'api-index', 'api-index-readme'],
        relPath: `${model.name}/README.md`
      };
    }

    // module index page (e.g. `equipment/Apparatus/README.md`)
    const segments = segment([titleCase(pkg.name), categoryOf(model)], model.name);

    return {
      title: segments.join('/'),
      name: model.name,
      tags: ['kind-module', 'api-index', 'api-index-module'],
      relPath: `${pkg.name}/${model.name}/README.md`
    };
  }

  const mod = model.parent;
  const pkg = mod?.parent;

  if (
    !Object.hasOwn(MARKDOWN_FOLDER, model.kind) ||
    model.kind === KIND.Reference ||
    !mod ||
    !pkg
  ) {
    return;
  }

  // members of a package module have no module level in between (barrel files)
  const base =
    pkg.kind === KIND.Project
      ? [titleCase(mod.name)]
      : [titleCase(pkg.name), categoryOf(mod), mod.name];

  const segments = segment(base, categoryOf(model));

  segments.push(model.name);

  const directory =
    pkg.kind === KIND.Project
      ? `${mod.name}/${MARKDOWN_FOLDER[model.kind]}`
      : `${pkg.name}/${mod.name}/${MARKDOWN_FOLDER[model.kind]}`;

  return {
    title: segments.join('/'),
    name: model.name,
    tags: [`kind-${KIND_NAME[model.kind]}`],
    relPath: `${directory}/${model.name}.md`,
    sourceFile: sourceTail(model.sources?.[0]?.fileName ?? model.sources?.[0]?.path)
  };
}

/**
 * Re-exported symbols of a package module, grouped by the category they are listed in
 */
function groupedReferencesOf(pkg, pagesById) {
  const categories = new Map();

  for (const child of pkg.children ?? []) {
    if (child.kind !== KIND.Reference) {
      continue;
    }

    const category = categoryOf(child);
    const target = pagesById.get(child.target ?? -1);

    if (!category || !target) {
      continue;
    }

    if (!categories.has(category)) {
      categories.set(category, []);
    }

    categories.get(category).push({ name: child.name, target });
  }

  return categories;
}

function collectRelevant(pkg) {
  const models = [pkg];

  for (const child of pkg.children ?? []) {
    models.push(child);

    if (child.kind === KIND.Module) {
      models.push(...(child.children ?? []));
    }
  }

  return models;
}

/** the JSON structure has no upward links — mirror TypeDoc's live reflection tree */
function linkParents(node) {
  for (const child of node.children ?? []) {
    child.parent = node;
    linkParents(child);
  }
}

/**
 * Derive everything the addon needs to know about the markdown pages of a TypeDoc project from
 * its JSON structure: page metas keyed by relative path, plus content of generated entry-point
 * index pages.
 */
function buildStructure(structure) {
  linkParents(structure);

  const pagesById = new Map();
  const pages = new Map();
  const packageDirs = new Map();

  for (const pkg of structure.children ?? []) {
    if (pkg.kind === KIND.Module) {
      packageDirs.set(pkg.id, pkg.name);
    }

    for (const model of collectRelevant(pkg)) {
      const meta = pageOf(model);

      if (meta && !pages.has(meta.relPath)) {
        pages.set(meta.relPath, meta);
        pagesById.set(model.id, meta);
      }
    }
  }

  const entryPoints = new Map();

  for (const pkg of structure.children ?? []) {
    const pkgDir = packageDirs.get(pkg.id);

    if (!pkgDir) {
      continue;
    }

    const entryPointDir = `${pkgDir}/${ENTRY_POINT_FOLDER}`;

    for (const [category, references] of groupedReferencesOf(pkg, pagesById)) {
      const relPath = `${entryPointDir}/${slugOf(category)}.md`;
      const meta = {
        title: `${titleCase(pkg.name)}/${category}`,
        name: category,
        tags: ['kind-entry-point'],
        relPath
      };
      const links = references.map(({ name, target }) => {
        return `- [${name}](${path.posix.relative(entryPointDir, target.relPath)})`;
      });

      entryPoints.set(relPath, `# ${category}\n\nRe-exported symbols:\n\n${links.join('\n')}\n`);

      if (!pages.has(relPath)) {
        pages.set(relPath, meta);
      }
    }
  }

  return { pages, entryPoints };
}

/**
 * Resolve the meta of a markdown page relative to the output directory.
 *
 * Falls back to a path-derived meta for pages the structure does not know about, e.g. overloads
 * typedoc-plugin-markdown suffixed into a new file name.
 */
function lookupPage(model, relPath) {
  const known = model.pages.get(relPath);

  if (known) {
    return known;
  }

  return model.pages.get(relPath.replaceAll(/_\d+\.md$/g, '.md'));
}

/** minimal page meta derived from the file path alone, for pages missing from the structure */
function pageFromPath(relPath) {
  const parsed = path.posix.parse(relPath);
  const directories = parsed.dir.split('/').filter(Boolean);
  const kind = KIND_FOLDER[directories.at(-1) ?? ''];

  if (kind) {
    directories.pop();
  }

  const segments = directories.map((value) => titleCase(value));

  segments.push(parsed.name);

  return {
    title: segments.join('/'),
    name: parsed.name,
    tags: kind ? [`kind-${kind}`] : [],
    relPath
  };
}

/** @type {{configDir: string, markdownDir: string, structureFile: string, options: object} | undefined} */
let state;
/** @type {{mtimeMs: number, model: object} | undefined} */
let structure;

function getState() {
  if (!state) {
    throw new Error('storybook-addon-typedoc: no Storybook config has been loaded yet');
  }

  return state;
}

/** (re)load the TypeDoc structure if it changed on disk, and materialize the generated pages */
function getStructure() {
  const { markdownDir, structureFile } = getState();
  let mtimeMs;

  try {
    mtimeMs = statSync(structureFile).mtimeMs;
  } catch {
    structure = undefined;

    return;
  }

  if (structure?.mtimeMs !== mtimeMs) {
    const json = JSON.parse(readFileSync(structureFile, 'utf8'));

    structure = { mtimeMs, model: buildStructure(json) };

    writeGeneratedPages(markdownDir, structure.model);
  }

  return structure.model;
}

function writeGeneratedPages(markdownDir, model) {
  // the project readme is not indexed, remove it so it cannot be picked up by other globs
  rmSync(path.join(markdownDir, 'README.md'), { force: true });

  const packages = new Set(Array.from(model.pages.keys(), (rel) => rel.split('/', 1)[0]));

  for (const pkg of packages) {
    rmSync(path.join(markdownDir, pkg, ENTRY_POINT_FOLDER), { force: true, recursive: true });
  }

  for (const [rel, content] of model.entryPoints) {
    const file = path.join(markdownDir, rel);

    mkdirSync(path.dirname(file), { recursive: true });
    writeFileSync(file, content);
  }
}

function resolvePage(relPath) {
  const model = getStructure();

  return (model && lookupPage(model, relPath)) || pageFromPath(relPath);
}

/** memoized per dev/build session: source file tail -> the storybook page that should win links */
let storyTargets;

/**
 * Collect, from the story index, where links to typedoc pages for components should go:
 * a component's autodocs page if it has one, otherwise its first story.
 */
async function getStoryTargets(presets) {
  if (storyTargets) {
    return storyTargets;
  }

  const generator = await presets.apply('storyIndexGenerator');
  const index = generator ? await generator.getIndex() : { entries: {} };
  const bySource = new Map();
  const sourceByTitle = new Map();
  const storyFiles = new Set();

  for (const entry of Object.values(index.entries)) {
    const source = entry.componentPath && sourceTail(entry.componentPath);

    if (!source) {
      continue;
    }

    storyFiles.add(entry.importPath);
    sourceByTitle.set(entry.title, source);

    if (entry.type === 'story' && entry.subtype !== 'test') {
      const target = bySource.get(source) ?? {};

      bySource.set(source, target);
      target.firstStoryId ??= entry.id;
    }
  }

  for (const entry of Object.values(index.entries)) {
    const source =
      entry.type === 'docs' && storyFiles.has(entry.importPath) && sourceByTitle.get(entry.title);
    const target = source && bySource.get(source);

    if (target) {
      target.docsId ??= entry.id;
    }
  }

  storyTargets = bySource;

  return bySource;
}

function relativeToMarkdown(fileName) {
  const { markdownDir } = getState();
  const rel = path.relative(markdownDir, fileName).split(path.sep).join('/');

  return rel.startsWith('..') ? undefined : rel;
}

/**
 * Initialize (or refresh) addon state from the preset hook options. Preset hooks receive the
 * addon `options` from main.ts merged with the Storybook options, e.g. `configDir`.
 */
function ensure(options) {
  const { configDir } = options;

  if (state?.configDir === configDir) {
    return state;
  }

  state = {
    configDir,
    markdownDir: path.resolve(configDir, options.markdownDir ?? '../apidocs/markdown'),
    structureFile: path.resolve(configDir, options.structureFile ?? '../apidocs/structure.json'),
    options: {
      iconScope: options.iconScope ?? 'leaf',
      hideIndexPages: options.hideIndexPages ?? true
    }
  };
  structure = undefined;

  return state;
}

/**
 * Index typedoc markdown files as standalone MDX docs pages (like a plain `.mdx` file): the
 * `unattached-mdx` tag makes the preview render the compiled MDX itself. Each file yields a
 * single `Docs` export entry, which Storybook pairs with a generated docs page entry on the
 * same id, keeping only the latter. All typedoc-specific tags ride along on the entry.
 */
export const experimental_indexers = (existingIndexers = [], options) => {
  ensure(options);

  // materialize the generated entry-point pages *before* the stories glob runs, so that
  // single-pass builds see them
  getStructure();

  return [
    ...existingIndexers,
    {
      test: /\.md$/,
      createIndex(fileName) {
        const rel = relativeToMarkdown(fileName);

        if (!rel) {
          return [];
        }

        const meta = resolvePage(rel);

        return [
          {
            type: 'story',
            exportName: DOCS_NAME,
            name: meta.name,
            title: meta.title,
            tags: ['autodocs', MDX_TAG, ...meta.tags]
          }
        ];
      }
    }
  ];
};

/** the `<Meta>` header that turns the markdown into a Storybook docs page */
function metaHeaderOf(meta) {
  const tags = meta.tags.map((tag) => JSON.stringify(tag)).join(', ');

  return [
    `import { Meta } from '@storybook/addon-docs/blocks';`,
    '',
    `<Meta title=${JSON.stringify(meta.title)} name=${JSON.stringify(meta.name)} tags={[${tags}]} />`,
    ''
  ].join('\n');
}

/**
 * Turn relative links to other typedoc pages (`[foo](../x/y.md)`) into documented Storybook
 * links (`[foo](?path=/docs/<id>)`), preserving `#section` fragments.
 *
 * Links to pages that describe a component with stories go to that component instead:
 * its autodocs page if it has one, otherwise its first story.
 *
 * Done per line outside of fenced code blocks — good enough for typedoc's markdown, and it
 * keeps this a pure string transformation.
 */
const LINK = /\[([^\]]*)\]\(([^)\s]+\.md)(#[^)]*)?\)/g;

function rewriteTypedocLinks(source, currentRel, targets) {
  const dir = path.posix.dirname(currentRel);

  function rewriteUrl(file, anchor) {
    const rel = path.posix.normalize(path.posix.join(dir, file));
    const meta = resolvePage(rel);
    const story = meta.sourceFile && targets.get(meta.sourceFile);

    if (story) {
      return story.docsId ? `?path=/docs/${story.docsId}` : `?path=/story/${story.firstStoryId}`;
    }

    return `?path=/docs/${docsIdOf(meta)}${anchor ?? ''}`;
  }

  let inFence = false;

  return source
    .split('\n')
    .map((line) => {
      if (/^\s*(?:```|~~~)/.test(line)) {
        inFence = !inFence;

        return line;
      }

      return inFence
        ? line
        : line.replaceAll(LINK, (_all, text, file, anchor) => {
            return `[${text}](${rewriteUrl(file, anchor)})`;
          });
    })
    .join('\n');
}

/** real `.md` path behind a virtual `.mdx` id, if it is one of ours */
function markdownOfMdxId(id) {
  const [file] = id.split('?');

  if (!file.endsWith('.mdx')) {
    return;
  }

  const { markdownDir } = getState();
  const abs = path.normalize(file.slice(0, -'.mdx'.length) + '.md');

  return abs.startsWith(`${markdownDir}${path.sep}`) ? abs : undefined;
}

/** absolute path of a typedoc `.md` import, or undefined if the id is not one of ours */
function markdownSource(id, importer) {
  const [file] = id.split('?');

  if (!file?.endsWith('.md')) {
    return;
  }

  const { markdownDir } = getState();
  const candidates = [];

  if (path.isAbsolute(file)) {
    candidates.push(file);
  } else {
    if (importer) {
      const [importerFile] = importer.split('?');

      candidates.push(path.resolve(path.dirname(importerFile), file));
    }

    candidates.push(path.resolve(getState().configDir, '..', file.replaceAll(/^\//, '')));
  }

  const prefix = `${markdownDir}${path.sep}`;

  return candidates
    .map((candidate) => path.normalize(candidate))
    .find((abs) => abs.startsWith(prefix));
}

/**
 * Serve typedoc `.md` files as virtual `.mdx` modules — a `<Meta>` header over the original
 * markdown with its internal links rewritten — so Storybook's own MDX pipeline does the rest.
 */
export const viteFinal = async (viteConfig, options) => {
  ensure(options);

  const virtualMdx = {
    name: 'storybook-addon-typedoc/md',
    enforce: 'pre',
    resolveId(id, importer) {
      const mdPath = markdownSource(id, importer);

      if (!mdPath) {
        return;
      }

      return `${mdPath.slice(0, -'.md'.length)}.mdx`;
    },
    async load(id) {
      const mdPath = markdownOfMdxId(id);

      if (!mdPath) {
        return;
      }

      // eslint-disable-next-line unicorn/no-this-outside-of-class
      this.addWatchFile(mdPath);

      if (!existsSync(mdPath)) {
        throw new Error(`storybook-addon-typedoc: missing generated markdown page ${mdPath}`);
      }

      const rel = relativeToMarkdown(mdPath);
      const targets = await getStoryTargets(options.presets);

      return [
        metaHeaderOf(resolvePage(rel)),
        rewriteTypedocLinks(readFileSync(mdPath, 'utf8'), rel, targets)
      ].join('\n');
    }
  };

  return {
    ...viteConfig,
    plugins: [...(viteConfig.plugins ?? []), virtualMdx]
  };
};

/**
 * The manager cannot read options passed to the preview, so generate a tiny entry module that
 * hands the resolved options to the addon's manager code.
 */
export const managerEntries = (existingEntries = [], options) => {
  const { configDir, options: addonOptions } = ensure(options);
  const dir = path.join(configDir, '..', 'node_modules', '.cache', 'storybook-addon-typedoc');
  const entry = path.join(dir, 'manager-entry.mjs');

  mkdirSync(dir, { recursive: true });
  writeFileSync(
    entry,
    [
      `import { setupTypedocManager } from ${JSON.stringify(path.join(HERE, 'manager-entry.tsx'))};`,
      `setupTypedocManager(${JSON.stringify(addonOptions)});`,
      ''
    ].join('\n')
  );

  return [...existingEntries, entry];
};

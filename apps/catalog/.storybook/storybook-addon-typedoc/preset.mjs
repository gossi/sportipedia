import {
  existsSync,
  mkdirSync,
  readdirSync,
  readFileSync,
  rmSync,
  statSync,
  writeFileSync
} from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { StoryIndexGenerator } from 'storybook/internal/core-server';
import { toId } from 'storybook/internal/csf';

const HERE = path.dirname(fileURLToPath(import.meta.url));

/** mirrors TypeDoc's `ReflectionKind` numeric flags */
const KIND = {
  Project: 1,
  Module: 2,
  Namespace: 4,
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

/**
 * meta + output path of the markdown page rendered for a reflection, if it gets one.
 * `labels` name the leaf of generated index pages in the sidebar.
 */
function pageOf(model, labels) {
  if (model.kind === KIND.Module) {
    const pkg = model.parent;

    // package index page (e.g. `equipment/README.md`)
    if (!pkg || pkg.kind === KIND.Project) {
      return {
        title: `${titleCase(model.name)}/${labels.package}`,
        name: labels.package,
        tags: ['kind-package', 'api-index', 'api-index-package'],
        relPath: `${model.name}/README.md`
      };
    }

    // module index page (e.g. `equipment/Apparatus/README.md`)
    const segments = segment(segment([titleCase(pkg.name)], categoryOf(model)), model.name);

    segment(segments, labels.module);

    return {
      title: segments.join('/'),
      name: labels.module,
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
 * its JSON structure: page metas keyed by relative path, plus synthesized bodies for package
 * index pages when `packageIndexExportsOnly` is on.
 */
function buildStructure(structure, options) {
  linkParents(structure);

  const pages = new Map();
  const metasById = new Map();
  const nodesById = new Map();

  for (const pkg of structure.children ?? []) {
    for (const model of collectRelevant(pkg)) {
      nodesById.set(model.id, model);

      const meta = pageOf(model, options.indexLabels);

      if (meta) {
        metasById.set(model.id, meta);

        if (!pages.has(meta.relPath)) {
          pages.set(meta.relPath, meta);
        }
      }
    }
  }

  const packageBodies = options.packageIndexExportsOnly
    ? packageExportsBodies(structure, nodesById, metasById)
    : new Map();

  return { pages, packageBodies };
}

/**
 * Exports-only bodies for the package index pages: every public export of a package — all of
 * its children but the submodules — listed under the same headings TypeDoc uses in the package
 * README (`@category`, falling back to the symbol kind), each entry linking to the page of the
 * symbol it points at. Packages without exports get no body, so their index page is not shown.
 */
function packageExportsBodies(structure, nodesById, metasById) {
  const bodies = new Map();

  for (const pkg of structure.children ?? []) {
    if (pkg.kind !== KIND.Module || pkg.parent?.kind !== KIND.Project) {
      continue;
    }

    const groups = exportGroupsOf(pkg, nodesById, metasById);

    if (groups.size > 0) {
      const sections = Array.from(groups, ([title, bullets]) => {
        return `## ${title}\n\n${bullets.join('\n')}\n`;
      });

      bodies.set(`${pkg.name}/README.md`, `${sections.join('\n')}\n`);
    }
  }

  return bodies;
}

/** exports of a package module as bullets, keyed by the heading TypeDoc would list them under */
function exportGroupsOf(pkg, nodesById, metasById) {
  /** @type {Map<string, string[]>} */
  const groups = new Map();

  for (const child of pkg.children ?? []) {
    if (child.kind === KIND.Module || child.kind === KIND.Namespace) {
      continue;
    }

    const exported = resolveExported(child, nodesById);
    const target = exported && metasById.get(exported.id);

    if (!target) {
      continue;
    }

    const title =
      categoryOf(child) ||
      titleCase(MARKDOWN_FOLDER[exported.kind] ?? KIND_NAME[exported.kind] ?? 'Exports');
    const bullets = groups.get(title) ?? [];

    groups.set(title, bullets);
    bullets.push(`- [${child.name}](${path.posix.relative(pkg.name, target.relPath)})`);
  }

  return groups;
}

/** follow a (possibly chained) re-export reference to the declaration it points at */
function resolveExported(child, nodesById) {
  let current = child;

  while (current?.kind === KIND.Reference) {
    current = nodesById.get(current.target);
  }

  return current;
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

/** remove files that must not be picked up by the stories glob */
function cleanStalePages(markdownDir) {
  // the project readme is not indexed, remove it so it cannot be picked up by other globs
  rmSync(path.join(markdownDir, 'README.md'), { force: true });

  for (const entry of readdirSync(markdownDir, { withFileTypes: true })) {
    if (entry.isDirectory()) {
      // pages of the obsolete generated entry-point mechanism
      rmSync(path.join(markdownDir, entry.name, 'entry-point'), { force: true, recursive: true });
    }
  }
}

/** (re)load the TypeDoc structure if it changed on disk */
function getStructure() {
  const { structureFile, options } = getState();
  let mtimeMs;

  try {
    mtimeMs = statSync(structureFile).mtimeMs;
  } catch {
    structure = undefined;

    return;
  }

  if (structure?.mtimeMs !== mtimeMs) {
    const json = JSON.parse(readFileSync(structureFile, 'utf8'));

    structure = { mtimeMs, model: buildStructure(json, options) };
  }

  return structure.model;
}

function resolvePage(relPath) {
  const model = getStructure();

  return (model && lookupPage(model, relPath)) || pageFromPath(relPath);
}

/** memoized per dev/build session: source file tail -> the storybook page that should win links */
let storyTargets;

/**
 * Collect, from a story index, where links to typedoc pages for components should go:
 * a component's autodocs page if it has one, otherwise its first story.
 */
function storyTargetsFromIndex(index) {
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

  return bySource;
}

async function getStoryTargets(presets) {
  if (!storyTargets) {
    const generator = await presets.apply('storyIndexGenerator');
    const index = generator ? await generator.getIndex() : { entries: {} };

    storyTargets = storyTargetsFromIndex(index);
  }

  return storyTargets;
}

/**
 * Drop typedoc pages from the story index when their component has stories of its own: links to
 * those pages already redirect to the component's story (same predicate, same source), so the
 * page is redundant in the sidebar and unreachable otherwise.
 */
function pruneShadowedDocs(index) {
  // no addon state loaded (e.g. an index-only tool in this process): nothing to prune
  if (!state || !index?.entries) {
    return index;
  }

  const model = getStructure();

  if (!model) {
    return index;
  }

  const targets = storyTargetsFromIndex(index);
  const entries = {};
  let pruned = false;

  for (const [id, entry] of Object.entries(index.entries)) {
    const rel =
      entry.tags?.includes(MDX_TAG) &&
      entry.importPath &&
      relativeToMarkdown(path.resolve(entry.importPath));
    const source = rel && lookupPage(model, rel)?.sourceFile;

    if (source && targets.has(source)) {
      pruned = true;
      continue;
    }

    entries[id] = entry;
  }

  return pruned ? { ...index, entries } : index;
}

/**
 * Typedoc pages for components that have stories of their own are redundant — links to them
 * already redirect to the component's story (the same predicate, applied at link time). Wrap
 * the story index generator's `getIndex` so those entries never reach Storybook at all: the
 * generator is a publicly exported class and the preset module is evaluated before any
 * instance exists, so patching the prototype covers dev, build, and every consumer.
 */
const generateIndex = StoryIndexGenerator.prototype.getIndex;

if (!generateIndex.shadowedDocsPruned) {
  StoryIndexGenerator.prototype.getIndex = async function () {
    // eslint-disable-next-line unicorn/no-this-outside-of-class
    return pruneShadowedDocs(await generateIndex.call(this));
  };

  StoryIndexGenerator.prototype.getIndex.shadowedDocsPruned = true;
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

  const showIndex = options.showIndex ?? false;

  state = {
    configDir,
    markdownDir: path.resolve(configDir, options.markdownDir ?? '../apidocs/markdown'),
    structureFile: path.resolve(configDir, options.structureFile ?? '../apidocs/structure.json'),
    options: {
      iconScope: options.iconScope ?? 'leaf',
      showIndexPackage: options.showIndexPackage ?? showIndex,
      showIndexModule: options.showIndexModule ?? showIndex,
      packageIndexExportsOnly: options.packageIndexExportsOnly ?? false,
      indexLabels: {
        package: options.indexLabels?.package ?? 'Package',
        module: options.indexLabels?.module ?? 'Module'
      }
    }
  };
  structure = undefined;

  return state;
}

/**
 * Index typedoc markdown files as standalone MDX docs pages (like a plain `.mdx` file): the
 * `unattached-mdx` tag makes the preview render the compiled MDX itself. Each file yields a
 * single `Docs` export entry — except package index pages without exports under
 * `packageIndexExportsOnly`, which are skipped — which Storybook pairs with a generated docs
 * page entry on the same id, keeping only the latter. All typedoc-specific tags ride along on
 * the entry.
 */
export const experimental_indexers = (existingIndexers = [], options) => {
  const { markdownDir } = ensure(options);

  // prune stale files *before* the stories glob runs, so that single-pass builds don't see them
  cleanStalePages(markdownDir);

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

        // exports-only: a package with no exports has no body and is not shown at all
        if (
          getState().options.packageIndexExportsOnly &&
          meta.tags.includes('api-index-package') &&
          !getStructure()?.packageBodies.get(rel)
        ) {
          return [];
        }

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
      const source = getStructure()?.packageBodies.get(rel) ?? readFileSync(mdPath, 'utf8');

      return [metaHeaderOf(resolvePage(rel)), rewriteTypedocLinks(source, rel, targets)].join('\n');
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

import { existsSync, mkdirSync, rmSync, unlinkSync, writeFileSync } from 'node:fs';
import path from 'node:path';

import { toId } from 'storybook/internal/csf';
import { PageEvent, ReferenceReflection, RendererEvent } from 'typedoc';

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

const META_IMPORT = "import { Meta } from '@storybook/addon-docs/blocks';";

/** folder and tag of the generated pages listing a package entry point's re-exported symbols */
const ENTRY_POINT_FOLDER = 'entry-point';
const ENTRY_POINT_TAG = 'kind-entry-point';

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

function metaFor(model) {
  if (model.kind === KIND.Module) {
    const pkg = model.parent;

    // package index page (e.g. `equipment/README.mdx`)
    if (!pkg || pkg.kind === KIND.Project) {
      const name = titleCase(model.name);

      return {
        title: name,
        name,
        tags: ['kind-module', 'api-index', 'api-index-readme']
      };
    }

    // module index page (e.g. `equipment/Apparatus/README.mdx`)
    const segments = segment([titleCase(pkg.name), categoryOf(model)], model.name);

    return {
      title: segments.join('/'),
      name: model.name,
      tags: ['kind-module', 'api-index', 'api-index-module']
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

  return {
    title: segments.join('/'),
    name: model.name,
    tags: [`kind-${KIND_NAME[model.kind]}`]
  };
}

function metaTagsOf(meta) {
  return `tags={[${meta.tags.map((tag) => `"${tag}"`).join(', ')}]}`;
}

function pageOf(meta) {
  return `${META_IMPORT}\n\n<Meta title="${meta.title}" name="${meta.name}" ${metaTagsOf(meta)} />\n\n`;
}

/**
 * Storybook cannot alias a sidebar entry, so the re-exports of a package's entry point get an
 * index page listing them, mirroring the "Re-exports" section of TypeDoc's own module page.
 */
function entryPointPageOf(pkgTitle, category, references) {
  const meta = { title: `${pkgTitle}/${category}`, name: category, tags: [ENTRY_POINT_TAG] };
  // target="_top" because docs pages render inside the manager's preview iframe
  const links = references.map(({ name, target }) => {
    return `- <a href="./?path=/docs/${toId(target.title, target.name)}" target="_top">${name}</a>`;
  });

  return `${pageOf(meta)}# ${category}\n\nRe-exported symbols:\n\n${links.join('\n')}\n`;
}

/** @param {import("typedoc").Application} app */
export function load(app) {
  let projectReadme;
  /**
   * Storybook titles of every rendered page, keyed by reflection id, so that
   * re-exports can link to the page of the symbol they point at.
   * @type {Map<number, { name: string, tags: string[], title: string }>}
   */
  const pages = new Map();
  /** Markdown directory per package module id, e.g. `apidocs/markdown/equipment`. */
  const packageDirs = new Map();

  app.renderer.on(PageEvent.END, (page) => {
    if (!page.filename.endsWith('.mdx')) {
      return;
    }

    if (page.model.kind === KIND.Project) {
      projectReadme = page.filename;

      return;
    }

    const meta = metaFor(page.model);

    if (!meta) {
      return;
    }

    pages.set(page.model.id, meta);

    if (page.model.parent?.kind === KIND.Project) {
      packageDirs.set(page.model.id, path.dirname(page.filename));
    }

    if (page.contents.startsWith(META_IMPORT)) {
      return;
    }

    page.contents = `${pageOf(meta)}${page.contents}`;
  });

  app.renderer.on(RendererEvent.END, (event) => {
    if (projectReadme && existsSync(projectReadme)) {
      unlinkSync(projectReadme);
    }

    writeEntryPointPages(event.project);
  });

  function writeEntryPointPages(project) {
    for (const pkg of project.children ?? []) {
      const directory = packageDirs.get(pkg.id);

      if (!directory) {
        continue;
      }

      const categories = groupedReferencesOf(pkg, pages);
      const entryPointDir = path.join(directory, ENTRY_POINT_FOLDER);

      rmSync(entryPointDir, { force: true, recursive: true });

      for (const [category, references] of categories) {
        mkdirSync(entryPointDir, { recursive: true });
        writeFileSync(
          path.join(entryPointDir, `${slugOf(category)}.mdx`),
          entryPointPageOf(titleCase(pkg.name), category, references)
        );
      }
    }
  }
}

/**
 * Re-exported symbols of a package module, grouped by the category they are listed in
 * @param {import("typedoc").DeclarationReflection} pkg
 * @param {Map<number, { name: string, title: string }>} pages
 */
function groupedReferencesOf(pkg, pages) {
  /** @type {Map<string, { name: string, target: { name: string, title: string } }[]>} */
  const categories = new Map();

  for (const child of pkg.children ?? []) {
    if (!(child instanceof ReferenceReflection)) {
      continue;
    }

    const category = categoryOf(child);
    const target = pages.get(child.tryGetTargetReflectionDeep()?.id);

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

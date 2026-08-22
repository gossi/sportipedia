import { existsSync, unlinkSync } from 'node:fs';

import { PageEvent, RendererEvent } from 'typedoc';

const KIND = {
  Project: 1,
  Module: 2,
  Variable: 32,
  Function: 64,
  Class: 128,
  Interface: 256,
  TypeAlias: 2_097_152,
  Reference: 4_194_304
};

const MARKDOWN_FOLDER = {
  [KIND.Interface]: 'interfaces',
  [KIND.Function]: 'functions',
  [KIND.Variable]: 'variables',
  [KIND.Class]: 'classes',
  [KIND.TypeAlias]: 'type-aliases'
};

const META_IMPORT = "import { Meta } from '@storybook/addon-docs/blocks';";

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

function metaFor(model) {
  if (model.kind === KIND.Module) {
    const pkg = model.parent;

    // package index page (e.g. `equipment/README.mdx`)
    if (!pkg || pkg.kind === KIND.Project) {
      const name = titleCase(model.name);

      return { title: name, name };
    }

    // module index page (e.g. `equipment/Apparatus/README.mdx`)
    const segments = segment([titleCase(pkg.name), categoryOf(model)], model.name);

    return { title: segments.join('/'), name: model.name };
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

  const segments = segment([titleCase(pkg.name), categoryOf(mod), mod.name], categoryOf(model));

  segments.push(model.name);

  return { title: segments.join('/'), name: model.name };
}

/** @param {import("typedoc").Application} app */
export function load(app) {
  let projectReadme;

  app.renderer.on(PageEvent.END, (page) => {
    if (!page.filename.endsWith('.mdx')) {
      return;
    }

    if (page.model.kind === KIND.Project) {
      projectReadme = page.filename;

      return;
    }

    const meta = metaFor(page.model);

    if (!meta || page.contents.startsWith(META_IMPORT)) {
      return;
    }

    page.contents = `${META_IMPORT}\n\n<Meta title="${meta.title}" name="${meta.name}" />\n\n${page.contents}`;
  });

  app.renderer.on(RendererEvent.END, () => {
    if (projectReadme && existsSync(projectReadme)) {
      unlinkSync(projectReadme);
    }
  });
}

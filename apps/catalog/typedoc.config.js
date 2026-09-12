/** @type {Partial<import("typedoc").TypeDocOptions>} */
export default {
  entryPoints: ['src/equipment', 'src/user', 'src/support'],
  entryPointStrategy: 'packages',
  skipErrorChecking: true,
  packageOptions: {
    skipErrorChecking: true,
    categoryOrder: ['Public API', 'Domain Object', 'Queries', 'Actions', 'Abilities', '*'],
    excludeInternal: true
  },
  categoryOrder: ['Public API', 'Domain Object', 'Queries', 'Actions', 'Abilities', '*'],
  name: '@sportipedia/catalog',
  outputs: [
    {
      name: 'json',
      path: './apidocs/structure.json'
    },
    {
      name: 'html',
      path: './apidocs/html',
      options: {
        navigation: {
          includeCategories: true,
          includeGroups: false,
          excludeReferences: false,
          includeFolders: false
        }
      }
    },
    {
      name: 'markdown',
      path: './apidocs/markdown',
      options: {
        fileExtension: '.mdx',
        hideBreadcrumbs: true,
        hidePageHeader: true
      }
    }
  ],
  plugin: [
    'typedoc-plugin-ember',
    'typedoc-plugin-markdown',
    'typedoc-plugin-inline-sources',
    './scripts/typedoc-plugin-storybook.mjs'
  ]
};

import { fileURLToPath } from 'node:url';

export default {
  plugins: [
    [
      '@babel/plugin-transform-typescript',
      {
        allExtensions: true,
        allowDeclareFields: true,
        onlyRemoveTypeImports: true
      }
    ],
    [
      'module:decorator-transforms',
      {
        runtime: {
          import: fileURLToPath(import.meta.resolve('decorator-transforms/runtime-esm'))
        }
      }
    ]
  ],

  generatorOpts: {
    compact: false
  }
};

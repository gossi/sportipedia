import { buildMacros } from '@embroider/macros/babel';
import { fileURLToPath } from 'node:url';

import { scopedCSS } from 'ember-scoped-css/babel';

const macros = buildMacros();

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
      'babel-plugin-ember-template-compilation',
      {
        transforms: [...macros.templateMacros, scopedCSS.template({ layerName: 'app' })]
      }
    ],
    [
      'module:decorator-transforms',
      {
        runtime: {
          import: fileURLToPath(import.meta.resolve('decorator-transforms/runtime-esm'))
        }
      }
    ],
    ...macros.babelMacros
  ],

  generatorOpts: {
    compact: false
  }
};

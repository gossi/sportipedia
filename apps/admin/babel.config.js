import { buildMacros } from '@embroider/macros/babel';
import { fileURLToPath } from 'node:url';

import { setConfig } from '@warp-drive/core/build-config';
import emberConcurrency from 'ember-concurrency/async-arrow-task-transform';

const macros = buildMacros({
  configure: (config) => {
    setConfig(config, {
      // this should be the most recent <major>.<minor> version for
      // which all deprecations have been fully resolved
      // and should be updated when that changes
      // for new apps it should be the version you installed
      // for universal apps this MUST be at least 5.6
      compatWith: '6.5'
    });
  }
});

export default {
  plugins: [
    [
      '@babel/plugin-transform-typescript',
      {
        allExtensions: true,
        onlyRemoveTypeImports: true,
        allowDeclareFields: true
      }
    ],
    [
      'babel-plugin-ember-template-compilation',
      {
        transforms: [...macros.templateMacros, 'glimmer-scoped-css/ast-transform']
      }
    ],
    emberConcurrency,
    [
      'module:decorator-transforms',
      {
        runtime: {
          import: fileURLToPath(import.meta.resolve('decorator-transforms/runtime-esm'))
        }
      }
    ],
    [
      '@babel/plugin-transform-runtime',
      {
        absoluteRuntime: import.meta.dirname,
        useESModules: true,
        regenerator: false
      }
    ],
    [
      'babel-plugin-debug-macros',
      {
        flags: [],

        debugTools: {
          isDebug: true,
          source: '@ember/debug',
          assertPredicateIndex: 1
        }
      },
      'ember-data-specific-macros-stripping-test'
    ],
    ...macros.babelMacros
  ],

  generatorOpts: {
    compact: false
  }
};

import { ember, extensions } from '@embroider/vite';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { babel } from '@rollup/plugin-babel';
import { storybookTest } from '@storybook/addon-vitest/vitest-plugin';
import { playwright } from '@vitest/browser-playwright';
import { intl } from 'ember-intl/vite';
import { scopedCSS } from 'ember-scoped-css/vite';
// import { FileSystemIconLoader } from 'unplugin-icons/loaders';
import icons from 'unplugin-icons/vite';
import { defineConfig } from 'vite';

const dirname = path.dirname(fileURLToPath(import.meta.url));

import { theemo } from '@theemo/vite';

export default defineConfig({
  define: {
    __API_URL__: JSON.stringify(process.env.API_URL),
    __AUTH_URL__: JSON.stringify(process.env.AUTH_URL)
  },
  server: {
    port: 4101
  },
  css: {
    transformer: 'lightningcss'
  },
  test: {
    projects: [
      {
        extends: true,
        test: {
          name: 'Business Logic',
          setupFiles: ['./tests/test-setup.ts']
        }
      },
      {
        extends: true,
        plugins: [
          storybookTest({
            configDir: path.join(dirname, '.storybook'),
            // This should match your package.json script to run Storybook
            // The --no-open flag will skip the automatic opening of a browser
            storybookScript: 'pnpm sb --no-open'
          })
        ],
        // pre-bundle the runtime template compiler: lazy discovery would trigger
        // a full reload mid-run and break the browser test runner
        optimizeDeps: {
          include: ['ember-source/@ember/template-compiler/index.js']
        },
        test: {
          name: 'storybook',
          browser: {
            enabled: true,
            provider: playwright({}),
            headless: true,
            instances: [{ browser: 'chromium' }]
          }
          // setupFiles: ['./.storybook/vitest.setup.ts']
        }
      }
    ]
  },
  plugins: [
    ember(),
    scopedCSS({ layerName: 'app' }),
    babel({
      babelHelpers: 'runtime',
      extensions
    }),
    theemo({
      defaultTheme: 'moana'
    }),
    icons({
      autoInstall: true,
      compiler: 'ember'
      // customCollections: {
      //   custom: FileSystemIconLoader('./assets/icons')
      // }
    }),
    intl({
      paths: [
        './locales',
        './node_modules/@sportipedia/user/locales',
        './node_modules/@sportipedia/ui/locales'
      ]
    }),
    {
      name: 'watch-locales',
      configureServer: (server) => {
        server.watcher.options = {
          ...server.watcher.options,
          ignored: [/node_modules\/(?!@sportipedia).*/, '**/.git/**']
        };
      }
    }
  ]
});

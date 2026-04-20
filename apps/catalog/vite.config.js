import { ember, extensions } from '@embroider/vite';

import { babel } from '@rollup/plugin-babel';
import { intl } from 'ember-intl/vite';
import { scopedCSS } from 'ember-scoped-css/vite';
// import { FileSystemIconLoader } from 'unplugin-icons/loaders';
import icons from 'unplugin-icons/vite';
import { defineConfig } from 'vite';

import { theemo } from '@theemo/vite';

export default defineConfig({
  define: {
    __API_URL__: JSON.stringify(process.env.API_URL),
    __AUTH_URL__: JSON.stringify(process.env.AUTH_URL)
  },
  server: {
    port: 4101
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
      paths: ['./locales', './node_modules/@sportipedia/user/locales']
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

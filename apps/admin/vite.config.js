import { ember, extensions } from '@embroider/vite';

import { babel } from '@rollup/plugin-babel';
import { intl } from 'ember-intl/vite';
import { scopedCSS } from 'glimmer-scoped-css/rollup';
// import { FileSystemIconLoader } from 'unplugin-icons/loaders';
import icons from 'unplugin-icons/vite';
import { defineConfig } from 'vite';

import { theemo } from '@theemo/vite';

export default defineConfig({
  server: {
    port: 4100
  },
  plugins: [
    ember(),
    scopedCSS('src'),
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
    })
  ]
});

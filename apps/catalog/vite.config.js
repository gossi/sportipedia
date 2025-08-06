import { ember, extensions } from '@embroider/vite';

import { babel } from '@rollup/plugin-babel';
// import { FileSystemIconLoader } from 'unplugin-icons/loaders';
import icons from 'unplugin-icons/vite';
import { defineConfig } from 'vite';

import { theemo } from '@theemo/vite';

export default defineConfig({
  plugins: [
    ember(),
    babel({
      babelHelpers: 'runtime',
      extensions
    }),
    theemo({
      defaultTheme: 'moana'
    }),
    icons({
      autoInstall: true,
      compiler: 'raw'
      // customCollections: {
      //   custom: FileSystemIconLoader('./assets/icons')
      // }
    })
  ]
});

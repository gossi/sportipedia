import { Addon } from '@embroider/addon-dev/rollup';
import { extensions } from '@embroider/vite';

import { babel } from '@rollup/plugin-babel';
import { scopedCSS } from 'ember-scoped-css/rollup';
import { defineConfig } from 'tsdown';
import icons from 'unplugin-icons/rollup';

const addon = new Addon({
  srcDir: 'src',
  destDir: 'dist'
});

export default defineConfig({
  entry: ['src/index.ts'],
  sourcemap: true,
  clean: true,
  dts: false,
  tsconfig: './tsconfig.build.json',
  plugins: [
    scopedCSS({ layerName: 'app' }),
    babel({
      babelHelpers: 'bundled',
      extensions
    }),
    addon.dependencies(),
    addon.gjs(),
    addon.declarations(
      'declarations',
      `ember-tsc --declaration --project ./tsconfig.declarations.json`
    ),
    icons({
      autoInstall: true,
      compiler: 'ember'
    })
  ],
  ignoreWatch: ['declarations/']
});

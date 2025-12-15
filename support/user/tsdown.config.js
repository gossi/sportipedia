import { Addon } from '@embroider/addon-dev/rollup';
import { extensions } from '@embroider/vite';

import { babel } from '@rollup/plugin-babel';
import { scopedCSS } from 'ember-scoped-css/rollup';
import { defineConfig } from 'tsdown';

const addon = new Addon({
  srcDir: 'src',
  destDir: 'dist'
});

export default defineConfig({
  entry: ['src/index.ts', 'src/registry.ts'],
  sourcemap: true,
  clean: true,
  dts: false,
  tsconfig: './tsconfig.build.json',
  plugins: [
    scopedCSS({ layerName: 'app' }),
    addon.dependencies(),
    addon.gjs(),
    addon.declarations('declarations', `ember-tsc --declaration --project ./tsconfig.publish.json`),
    babel({
      babelHelpers: 'bundled',
      extensions
    })
  ]
});

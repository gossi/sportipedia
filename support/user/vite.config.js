import { ember, extensions } from '@embroider/vite';

import { babel } from '@rollup/plugin-babel';
import { scopedCSS } from 'ember-scoped-css/vite';
import { defineConfig } from 'vite';

export default defineConfig({
  define: {
    __AUTH_URL__: JSON.stringify(process.env.AUTH_URL)
  },
  plugins: [
    ember(),
    scopedCSS({ layerName: 'app' }),
    babel({
      babelHelpers: 'inline',
      extensions
    })
  ],
  build: {
    rollupOptions: {
      input: {
        tests: 'tests/index.html'
      }
    }
  }
});

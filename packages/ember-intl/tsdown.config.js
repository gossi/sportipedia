import { defineConfig } from 'tsdown';

export default defineConfig({
  entry: ['src/index.ts', 'src/vite.ts', 'src/registry.ts', 'src/types.d.ts'],
  sourcemap: true,
  clean: true,
  dts: true,
  external: [
    '@ember/service',
    '@glimmer/tracking',
    '@ember/runloop',
    '@ember/template',
    '@formatjs/intl',
    'vite',
    'fsevents',
    /\.node$/
  ],
  tsconfig: './tsconfig.build.json'
});

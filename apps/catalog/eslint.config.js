import { defineConfig } from 'eslint/config';

import ember from '@gossi/config-eslint/ember';

export default defineConfig([
  {
    ignores: ['src/.storybook/storybook-addon-typedoc/*.jsx', 'apidocs/']
  },
  ...ember(import.meta.dirname),
  {
    files: ['src/**/*.ts', 'src/**/*.gts'],
    rules: {
      'unicorn/consistent-class-member-order': 'off'
    }
  }
]);

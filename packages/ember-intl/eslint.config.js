import ember from '@gossi/config-eslint/ember';

export default [
  ...ember(import.meta.dirname),
  {
    files: ['src/**/*.ts'],
    rules: {
      'unicorn/consistent-class-member-order': 'off'
    }
  }
];

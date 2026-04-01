import ember from '@gossi/config-eslint/ember';

export default [
  ...ember(import.meta.dirname),
  {
    files: ['./src/components/user-agent.gts'],
    rules: { '@typescript-eslint/no-unsafe-assignment': 'off' }
  }
];

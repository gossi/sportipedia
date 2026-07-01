import config from '@gossi/config-template-lint';

export default {
  ...config,

  plugins: [...config.plugins, 'ember-scoped-css/src/template-lint/plugin'],

  rules: {
    ...config.rules,
    'no-negated-condition': false,
    'no-passed-in-event-handlers': false,
    'no-forbidden-elements': ['meta', 'html', 'script']
  }
};

import type { StorybookConfig } from 'ember-storybook';

const config: StorybookConfig = {
  stories: ['../src/**/*.stories.gts', '../apidocs/markdown/*/**/*.mdx'],
  addons: ['@storybook/addon-docs', '@storybook/addon-a11y', '@storybook/addon-vitest'],
  framework: {
    name: 'ember-storybook',
    options: {}
  },
  features: {},
  core: {
    disableWhatsNewNotifications: true
  }
};

export default config;

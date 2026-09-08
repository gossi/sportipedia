import type { StorybookConfig } from 'ember-storybook';

const config: StorybookConfig = {
  stories: ['../src/**/*.stories.gts', '../apidocs/markdown/*/**/*.mdx'],
  staticDirs: ['../public'],
  addons: [
    '@storybook/addon-docs',
    '@storybook/addon-a11y',
    '@storybook/addon-vitest',
    'msw-storybook-addon'
  ],
  framework: {
    name: 'ember-storybook',
    options: {}
  },
  refs: {
    hokulea: {
      title: 'Hokulea',
      url: 'https://hokulea.netlify.app/ember/',
      expanded: false
    }
  },
  features: {
    sidebarOnboardingChecklist: false
  },
  core: {
    disableWhatsNewNotifications: true
  }
};

export default config;

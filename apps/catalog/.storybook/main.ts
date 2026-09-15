import { defineMain } from 'ember-storybook/node';

export default defineMain({
  stories: ['../src/**/*.stories.gts', '../apidocs/markdown/*/**/*.md'],
  staticDirs: ['../public'],
  addons: [
    '@storybook/addon-docs',
    '@storybook/addon-a11y',
    '@storybook/addon-vitest',
    'msw-storybook-addon',
    'storybook-addon-test-codegen',
    {
      name: './storybook-addon-typedoc/preset.mjs',
      options: {
        iconScope: 'leaf',
        showIndexPackage: true,
        packageIndexExportsOnly: true,
        indexLabels: { package: 'Public API' }
      }
    }
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
});

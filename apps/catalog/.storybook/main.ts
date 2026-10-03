import { defineMain } from 'ember-storybook/node';

export default defineMain({
  stories: ['../src/**/*.stories.gts', '../apidocs/markdown/**/*.md'],
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
  },
  viteFinal: (config) => {
    if (config.optimizeDeps?.include?.includes('react-dom/client')) {
      const index = config.optimizeDeps.include.indexOf('react-dom/client');

      config.optimizeDeps.include.splice(index, 1);
    }

    return config;
  }
});

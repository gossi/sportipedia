import { themes } from 'storybook/theming';

import { createApp } from '#/app';
import { configure } from '#/config';

import '@hokulea/core/style.css';

import type { Preview } from 'ember-storybook';

const preview: Preview = {
  parameters: {
    docs: {
      codePanel: true,
      theme: themes.dark
    },
    ember: {
      app: (options: Record<string, unknown> = {}) => createApp(options),
      configure
    },
    options: {
      storySort: {
        order: [
          'Equipment',
          [
            'Public API',
            'Domain Objects',
            ['*', ['Domain Object', 'Queries', 'Actions', 'Abilities']],
            'UI',
            '*'
          ],
          '*'
        ]
      }
    }
  },

  tags: ['vitest', 'autodocs']
};

export default preview;

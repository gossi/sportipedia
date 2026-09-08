import '../src/ui/app.css';

import { mswLoader } from 'msw-storybook-addon/csf3';
import { themes } from 'storybook/theming';

import { createApp } from '#/app';
import { configure } from '#/config';

import { authHandlers } from './msw-handlers';

import type { Preview } from 'ember-storybook';

const preview: Preview = {
  loaders: [mswLoader()],
  parameters: {
    msw: {
      handlers: authHandlers
    },
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

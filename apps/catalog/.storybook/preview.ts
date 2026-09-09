import '../src/ui/app.css';

import { mswLoader } from 'msw-storybook-addon/csf3';
import { themes } from 'storybook/theming';

import { createApp } from '#/app';
import { configure } from '#/config';

import { authHandlers } from './msw-handlers';
import { StoryAuthService } from './story-auth-service';

import type { SessionChoice } from './story-auth-service';
import type Owner from '@ember/owner';
import type { Preview } from 'ember-storybook';

const preview: Preview = {
  loaders: [mswLoader()],
  globalTypes: {
    locale: {
      description: 'Internationalization locale (ember-intl)',
      defaultValue: 'en',
      toolbar: {
        title: 'Locale',
        icon: 'globe',
        items: [
          { value: 'en', title: 'English' },
          { value: 'de', title: 'Deutsch' }
        ],
        dynamicTitle: true
      }
    },
    session: {
      description: 'Current session user (fixture)',
      defaultValue: 'guest',
      toolbar: {
        title: 'Session',
        icon: 'user',
        items: [
          { value: 'guest', title: 'Guest' },
          { value: 'user', title: 'User' },
          { value: 'admin', title: 'Admin' }
        ],
        dynamicTitle: true
      }
    }
  },
  initialGlobals: {
    locale: 'en',
    session: 'guest'
  },
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
      configure,
      owner: {
        'service:auth': StoryAuthService
      },
      updateGlobals(globals: Record<string, unknown>, owner: Owner): void {
        (owner.lookup('service:auth') as StoryAuthService).setSession(
          globals.session as SessionChoice
        );
        owner.lookup('service:intl').setLocale(globals.locale as string);
      }
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

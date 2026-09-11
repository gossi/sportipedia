import '../src/ui/app.css';

import addonA11y from '@storybook/addon-a11y';
import addonDocs from '@storybook/addon-docs';
import addonVitest from '@storybook/addon-vitest';
import { definePreview } from 'ember-storybook';
import { setupWorker } from 'msw/browser';
import addonMsw from 'msw-storybook-addon';
import { themes } from 'storybook/theming';
import addonCodegen from 'storybook-addon-test-codegen';

import { createApp } from '#/app';
import { configure } from '#/config';

import { authHandlers } from './msw-handlers';
import { StoryAuthService } from './story-auth-service';

import type { SessionChoice } from './story-auth-service';
import type Owner from '@ember/owner';

export default definePreview({
  addons: [
    addonDocs(),
    addonVitest(),
    addonMsw(async () => {
      const worker = setupWorker(...authHandlers);

      await worker.start();

      return worker;
    }),
    addonA11y(),
    addonCodegen()
  ],
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
  // beforeEach: ({ msw }) => {
  //   msw.use(...authHandlers);
  // },
  parameters: {
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

  tags: ['autodocs']
});

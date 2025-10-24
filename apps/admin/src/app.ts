import '@warp-drive/ember/install';

import EmberRouter from '@ember/routing/router';

import { userRegistry } from '@sportipedia/user/registry';
import { IntlService } from 'ember-intl';
import PageTitleService from 'ember-page-title/services/page-title';
import EmberApp from 'ember-strict-application-resolver';

import '@hokulea/core/index.css';
import { hokuleaRegistry } from '@hokulea/ember/registry';

import type ApplicationInstance from '@ember/application/instance';

export default class Router extends EmberRouter {
  location = 'history';
  rootURL = '/';
}

Router.map(function () {
  /* eslint-disable @typescript-eslint/no-invalid-this */
  this.route('login');
  this.route('logout');
  this.route('registration');
  this.route('protected', { path: '' }, function () {
    this.route('dashboard');
    this.route('users', function () {
      this.route('new');
      this.route('details', { path: '/:id' });
    });
  });
  /* eslint-enable @typescript-eslint/no-invalid-this */
});

export default class App extends EmberApp {
  modules = {
    './router': { default: Router },
    ...hokuleaRegistry(),
    ...userRegistry(),
    ...import.meta.glob('./services/**/*', { eager: true }),
    ...import.meta.glob('./routes/**/*', { eager: true }),
    ...import.meta.glob('./templates/**/*', { eager: true }),
    './services/intl': { default: IntlService },
    './services/page-title': { default: PageTitleService }
  };
}

export function createApp(options: Record<string, unknown> = {}) {
  const app = App.create({ ...options, autoboot: false });

  return app.buildInstance();
}

export async function start(instance: ApplicationInstance) {
  await instance.boot();

  instance.startRouting();
}

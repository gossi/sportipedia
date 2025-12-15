import '@warp-drive/ember/install';
import 'temporal-polyfill/global';

import EmberRouter from '@ember/routing/router';

import { userRegistry } from '@sportipedia/user/registry';
import { intlRegistry } from 'ember-intl/registry';
import { LinkManagerService } from 'ember-link';
import PageTitleService from 'ember-page-title/services/page-title';
import EmberApp from 'ember-strict-application-resolver';

// import '@hokulea/core/style.css';
import { hokuleaRegistry } from '@hokulea/ember/registry';

import type ApplicationInstance from '@ember/application/instance';

class Router extends EmberRouter {
  location = 'history';
  rootURL = '/';
}

Router.map(function () {
  /* eslint-disable @typescript-eslint/no-invalid-this */
  this.route('login');
  this.route('logout');
  this.route('registration');
  this.route('user', function () {
    this.route('profile');
    this.route('sessions');
    this.route('auth');
  });
  /* eslint-enable @typescript-eslint/no-invalid-this */
});

export default class App extends EmberApp {
  modules = {
    './router': { default: Router },
    ...hokuleaRegistry(),
    ...userRegistry(),
    ...intlRegistry(),
    ...import.meta.glob('./services/**/*.{ts,gts}', { eager: true }),
    ...import.meta.glob('./routes/**/*.{ts,gts}', { eager: true }),
    ...import.meta.glob('./templates/**/*.{ts,gts}', { eager: true }),
    './services/page-title': { default: PageTitleService },
    './services/link-manager': { default: LinkManagerService }
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

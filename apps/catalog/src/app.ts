import '@warp-drive/ember/install';
import 'temporal-polyfill/global';

import EmberRouter from '@ember/routing/router';

import { userRegistry as sharedUserRegistry } from '@sportipedia/user/registry';
import { intlRegistry } from 'ember-intl/registry';
import { LinkManagerService } from 'ember-link';
import PageTitleService from 'ember-page-title/services/page-title';
import EmberApp from 'ember-strict-application-resolver';

import { equipmentRegistry, equipmentRoutes } from '#equipment';
import { Store } from '#support/data';
import { userRegistry, userRoutes } from '#user';

import { hokuleaRegistry } from '@hokulea/ember/registry';

import { ApplicationTemplate } from './ui/application.gts';
import { IndexTemplate } from './ui/index.gts';
import { PingTemplate } from './ui/ping.gts';

import type ApplicationInstance from '@ember/application/instance';

class Router extends EmberRouter {
  location = 'history';
  rootURL = '/';
}

// eslint-disable-next-line unicorn/no-top-level-side-effects
Router.map(function () {
  /* eslint-disable @typescript-eslint/no-invalid-this, unicorn/no-this-outside-of-class */
  this.route('ping');

  userRoutes(this);
  equipmentRoutes(this);
  /* eslint-enable @typescript-eslint/no-invalid-this, unicorn/no-this-outside-of-class */
});

export default class App extends EmberApp {
  modules = {
    // external libs
    ...hokuleaRegistry(),
    ...sharedUserRegistry(),
    ...intlRegistry(),
    // constituents
    ...equipmentRegistry(),
    ...userRegistry(),
    // application concerns
    './router': { default: Router },
    './templates/application': ApplicationTemplate,
    './templates/index': IndexTemplate,
    './templates/ping': PingTemplate,
    './services/store': Store,
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

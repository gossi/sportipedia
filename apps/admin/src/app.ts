import '@warp-drive/ember/install';

import Application from '@ember/application';

import Resolver from 'ember-resolver';

import '@hokulea/core/index.css';

import config from './config';
import { registry } from './registry';

class App extends Application {
  modulePrefix = config.modulePrefix;
  Resolver = Resolver.withModules(registry);
}

export async function start(options: Record<string, unknown> = {}) {
  const app = App.create({ ...options, autoboot: false });

  const instance = app.buildInstance();

  await instance.boot();

  instance.startRouting();

  return instance;
}

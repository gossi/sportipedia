import '@warp-drive/ember/install';

import Application from '@ember/application';

import Resolver from 'ember-resolver';

import '@hokulea/core/index.css';

import config from './config';
import { registry } from './registry';

export default class App extends Application {
  modulePrefix = config.modulePrefix;
  Resolver = Resolver.withModules(registry);
}

import EmberRouter from '@ember/routing/router';

import config from './config';

export default class Router extends EmberRouter {
  location = config.locationType;
  rootURL = config.rootURL;
}

Router.map(function () {
  /* eslint-disable @typescript-eslint/no-invalid-this */
  this.route('auth', { path: '/auth/:provider' }, function () {
    this.route('callback');
  });
  this.route('login');
  /* eslint-enable @typescript-eslint/no-invalid-this */
});

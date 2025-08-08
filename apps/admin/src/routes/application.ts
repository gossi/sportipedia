import Route from '@ember/routing/route';
import { service } from '@ember/service';

import { SportipediaOauthAuthenticator } from '@sportipedia/auth';

import type { SessionService } from 'ember-auth';

export default class ApplicationRoute extends Route {
  @service declare session: SessionService;
  beforeModel() {
    this.session.registerAuthenticator(
      new SportipediaOauthAuthenticator({
        name: 'oauth'
      })
    );
  }
}

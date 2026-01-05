import Route from '@ember/routing/route';
import { service } from '@ember/service';

import { type AuthService, isAdmin } from '@sportipedia/user';

import type Transition from '@ember/routing/transition';

export default class UserRoute extends Route {
  @service declare auth: AuthService;

  async beforeModel(transition: Transition) {
    const authenticated = await this.auth.requireAuthentication(transition);

    if (authenticated && this.auth.user ? !isAdmin(this.auth.user) : true) {
      this._router.transitionTo('login');
    }
  }
}

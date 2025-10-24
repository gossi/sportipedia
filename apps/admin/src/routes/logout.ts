import Route from '@ember/routing/route';
import { service } from '@ember/service';

import type { AuthService } from '@sportipedia/user';

export default class LogoutRoute extends Route {
  @service declare auth: AuthService;

  async beforeModel() {
    await this.auth.client.signOut();
  }
}

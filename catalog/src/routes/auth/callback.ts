import Route from '@ember/routing/route';
import { service } from '@ember/service';

import type Transition from '@ember/routing/transition';
import type SessionService from '#/services/session';

type QP = {
  code: string;
  state: string;
};

export default class AuthCallbackRoute extends Route {
  @service declare session: SessionService;

  activate(transition: Transition) {
    const { provider } = this.paramsFor('auth') as { provider: string };
    const { code, state } = transition.to?.queryParams as QP;

    console.log('activate', { provider, code, state });

    void this.session.authenticate(provider, code, { state });
  }
}

import Route from '@ember/routing/route';
import { service } from '@ember/service';

import { restoreOauthSessionData, verifyOauthSession } from 'ember-auth';

import type Transition from '@ember/routing/transition';
import type { SessionService } from 'ember-auth';

type QP = {
  code: string;
  state: string;
};

export default class AuthCallbackRoute extends Route {
  @service declare session: SessionService;

  activate(transition: Transition) {
    const { provider } = this.paramsFor('auth') as { provider: string };
    const qp = new URLSearchParams(transition.to?.queryParams as QP);

    const sessionData = restoreOauthSessionData();

    if (!verifyOauthSession(sessionData, qp)) {
      console.error('eek, not verified');
    }

    void this.session.authenticate('oauth', {
      provider,
      code: qp.get('code'),
      codeVerifier: sessionData.codeVerifier
    });
  }
}

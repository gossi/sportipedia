import Service from '@ember/service';

import EventManager from '../-utils/event-manager.ts';
import SessionHandler from '../handler.ts';

import type { Authenticator } from '../authenticators/authenticator.ts';
import type { AuthenticatorData, SessionStore } from '../session-stores/store.ts';
import type Owner from '@ember/owner';

interface SessionEvents {
  authenticationSucceeded: [AuthenticatorData];
  invalidationSucceeded: [];
}

export default class SessionService extends Service {
  #handler: SessionHandler;
  #events = new EventManager<SessionEvents>();

  constructor(owner: Owner) {
    super(owner);

    this.#handler = new SessionHandler();

    this.#handler.on('authenticationSucceeded', (data: AuthenticatorData) =>
      this.#events.dispatchEvent('authenticationSucceeded', data)
    );

    this.#handler.on('invalidationSucceeded', () =>
      this.#events.dispatchEvent('invalidationSucceeded')
    );
  }

  registerAuthenticator(authenticator: Authenticator) {
    this.#handler.registerAuthenticator(authenticator);
  }

  setStore(store: SessionStore) {
    this.#handler.setStore(store);
  }

  async authenticate(name: string, data: unknown) {
    await this.#handler.authenticate(name, data);
  }

  async invalidate(...args: unknown[]) {
    await this.#handler.invalidate(...args);
  }

  async restore() {
    await this.#handler.restore();
  }
}

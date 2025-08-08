import Service from '@ember/service';

import { type Subscriber } from '../-utils/observer.ts';
import SessionHandler, { type SessionEvents } from '../handler.ts';

import type { Authenticator } from '../authenticators/authenticator.ts';
import type { SessionStore } from '../session-stores/store.ts';
import type Owner from '@ember/owner';

export default class SessionService extends Service {
  #handler: SessionHandler;

  constructor(owner: Owner) {
    super(owner);

    this.#handler = new SessionHandler();
  }

  subscribe<E extends keyof SessionEvents>(event: E, cb: Subscriber<SessionEvents, E>) {
    this.#handler.subscribe(event, cb);
  }

  unsubscribe<E extends keyof SessionEvents>(event: E, cb: Subscriber<SessionEvents, E>) {
    this.#handler.unsubscribe(event, cb);
  }

  registerAuthenticator(authenticator: Authenticator) {
    this.#handler.registerAuthenticator(authenticator);
  }

  setStore(store: SessionStore) {
    this.#handler.setStore(store);
  }

  get authenticated() {
    return this.#handler.authenticated;
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

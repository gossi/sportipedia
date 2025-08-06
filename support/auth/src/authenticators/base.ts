import EventManager, { type EventListener } from '../-utils/event-manager.ts';

import type { AuthenticatorEvents } from './authenticator.ts';

export default class BaseAuthenticator {
  #events = new EventManager<AuthenticatorEvents>();

  on<E extends keyof AuthenticatorEvents>(event: E, cb: EventListener<AuthenticatorEvents, E>) {
    this.#events.addEventListener(event, cb);
  }

  off<E extends keyof AuthenticatorEvents>(event: E, cb: EventListener<AuthenticatorEvents, E>) {
    this.#events.removeEventListener(event, cb);
  }

  trigger<E extends keyof AuthenticatorEvents>(event: E, ...value: AuthenticatorEvents[E]) {
    this.#events.dispatchEvent(event, ...value);
  }
}

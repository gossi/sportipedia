import Publisher, { type Subscriber } from '../-utils/observer.ts';

import type { Authenticator, AuthenticatorEvents } from './authenticator.ts';

interface AuthenticatorConfig {
  name: string;
}

export abstract class BaseAuthenticator implements Authenticator {
  protected publisher = new Publisher<AuthenticatorEvents>();
  protected config: AuthenticatorConfig;

  constructor(config: AuthenticatorConfig) {
    this.config = config;
  }

  get name() {
    return this.config.name;
  }

  subscribe<E extends keyof AuthenticatorEvents>(event: E, cb: Subscriber<AuthenticatorEvents, E>) {
    this.publisher.subscribe(event, cb);
  }

  unsubscribe<E extends keyof AuthenticatorEvents>(
    event: E,
    cb: Subscriber<AuthenticatorEvents, E>
  ) {
    this.publisher.unsubscribe(event, cb);
  }

  abstract authenticate(data: unknown): Promise<unknown>;
  abstract invalidate(data: unknown, ...args: unknown[]): Promise<void>;
  abstract restore(data: unknown): Promise<unknown>;
}

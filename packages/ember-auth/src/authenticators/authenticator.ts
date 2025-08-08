import type { Subscriber } from '../-utils/observer.ts';
import type { AuthenticatorData } from '../session-stores/store.ts';

export interface AuthenticatorEvents {
  dataUpdated: [AuthenticatorData];
  dataInvalidated: [];
}

export interface Authenticator<Payload = unknown, Data = unknown> {
  readonly name: string;

  authenticate(data: Payload): Promise<Data>;
  invalidate(data: Data, ...args: unknown[]): Promise<void>;
  restore(data: Data): Promise<Data>;

  subscribe<E extends keyof AuthenticatorEvents>(
    event: E,
    cb: Subscriber<AuthenticatorEvents, E>
  ): void;
  unsubscribe<E extends keyof AuthenticatorEvents>(
    event: E,
    cb: Subscriber<AuthenticatorEvents, E>
  ): void;
}

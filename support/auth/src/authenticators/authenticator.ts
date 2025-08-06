import type { EventListener } from '../-utils/event-manager.ts';
import type { AuthenticatorData } from '../session-stores/store.ts';

export interface AuthenticatorEvents {
  sessionDataUpdated: [AuthenticatorData];
  sessionDataInvalidated: [];
}

export interface Authenticator<Payload = unknown, Data = unknown> {
  readonly name: string;

  authenticate(data: Payload): Promise<Data>;
  invalidate(data: Data, ...args: unknown[]): Promise<void>;
  restore(data: Payload): Promise<Data>;

  on<E extends keyof AuthenticatorEvents>(
    event: E,
    cb: EventListener<AuthenticatorEvents, E>
  ): void;
  off<E extends keyof AuthenticatorEvents>(
    event: E,
    cb: EventListener<AuthenticatorEvents, E>
  ): void;
  trigger<E extends keyof AuthenticatorEvents>(event: E, ...value: AuthenticatorEvents[E]): void;
}

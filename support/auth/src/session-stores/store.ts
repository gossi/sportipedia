import type { EventListener } from '../-utils/event-manager.ts';

export type AuthenticatorData = unknown;

export type StoreData = {
  authenticated?: {
    authenticator: string;
    content?: AuthenticatorData;
  };
};

export interface StoreEvents {
  sessionDataUpdated: [StoreData];
}

export interface SessionStore {
  persist(data: StoreData): Promise<unknown>;
  restore(): Promise<StoreData>;
  clear(data: StoreData): Promise<unknown>;

  on<E extends keyof StoreEvents>(event: E, cb: EventListener<StoreEvents, E>): void;
  off<E extends keyof StoreEvents>(event: E, cb: EventListener<StoreEvents, E>): void;
  trigger<E extends keyof StoreEvents>(event: E, ...value: StoreEvents[E]): void;
}

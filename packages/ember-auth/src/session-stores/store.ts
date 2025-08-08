import type { Subscriber } from '../-utils/observer.ts';

export type AuthenticatorData = unknown;

export type StoreData = {
  authenticated?: {
    authenticator: string;
    data?: AuthenticatorData;
  };
};

export interface StoreEvents {
  storeDataUpdated: [StoreData];
}

export interface SessionStore {
  persist(data: StoreData): Promise<unknown>;
  restore(): Promise<StoreData>;
  clear(data: StoreData): Promise<unknown>;

  subscribe<E extends keyof StoreEvents>(event: E, cb: Subscriber<StoreEvents, E>): void;
  unsubscribe<E extends keyof StoreEvents>(event: E, cb: Subscriber<StoreEvents, E>): void;
}

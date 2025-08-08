import { tracked } from '@glimmer/tracking';
import { assert } from '@ember/debug';
import { registerDestructor } from '@ember/destroyable';

import Publisher, { type Subscriber } from './-utils/observer.ts';
import LocalStorageStore from './session-stores/local-storage.ts';

import type { Authenticator } from './authenticators/authenticator.ts';
import type { AuthenticatorData, SessionStore, StoreData } from './session-stores/store.ts';

export interface SessionEvents {
  authenticationSucceeded: [AuthenticatorData];
  authenticationFailed: [unknown];
  invalidationSucceeded: [];
  invalidationFailed: [unknown];
}

export default class SessionHandler {
  #publisher = new Publisher<SessionEvents>();

  #store!: SessionStore;

  #authenticators = new Map<string, Authenticator>();
  #authenticator?: Authenticator;
  #authenticatorData: AuthenticatorData = undefined;

  @tracked authenticated = false;

  constructor() {
    this.setStore(new LocalStorageStore());

    registerDestructor(this, () => this.#unregisterStore(this.#store));
  }

  // #region Store

  setStore(store: SessionStore) {
    // eslint-disable-next-line @typescript-eslint/no-unnecessary-condition
    if (this.#store) {
      this.#unregisterStore(this.#store);
    }

    this.#store = store;
    this.#store.subscribe('storeDataUpdated', this.#handleStoreDataUpdate);
  }

  #unregisterStore(store: SessionStore) {
    store.unsubscribe('storeDataUpdated', this.#handleStoreDataUpdate);
  }

  #handleStoreDataUpdate = async (data: StoreData) => {
    await this.#restoreFromStore(data);
  };

  async #updateStore() {
    if (this.authenticated && this.#authenticator) {
      const storeData: StoreData = {
        authenticated: {
          authenticator: this.#authenticator.name,
          data: this.#authenticatorData
        }
      };

      await this.#store.persist(storeData);
    } else {
      await this.#store.persist({});
    }
  }

  // #region PubSub

  subscribe<E extends keyof SessionEvents>(event: E, cb: Subscriber<SessionEvents, E>) {
    this.#publisher.subscribe(event, cb);
  }

  unsubscribe<E extends keyof SessionEvents>(event: E, cb: Subscriber<SessionEvents, E>) {
    this.#publisher.unsubscribe(event, cb);
  }

  // #region Authenticator

  registerAuthenticator(authenticator: Authenticator) {
    this.#authenticators.set(authenticator.name, authenticator);
  }

  #subscribeToAuthenticator(authenticator: Authenticator) {
    authenticator.subscribe('dataUpdated', this.#handleAuthenticatorDataUpdated);
    authenticator.subscribe('dataInvalidated', this.#handleAuthenticatorDataInvalidated);
  }

  #unsubscribeToAuthenticator(authenticator: Authenticator) {
    authenticator.unsubscribe('dataUpdated', this.#handleAuthenticatorDataUpdated);
    authenticator.unsubscribe('dataInvalidated', this.#handleAuthenticatorDataInvalidated);
  }

  #handleAuthenticatorDataUpdated = async (data: AuthenticatorData) => {
    this.#authenticatorData = data;
    await this.#updateStore();
  };

  #handleAuthenticatorDataInvalidated = async () => {
    await this.#handleInvalidation();
  };

  #lookupAuthenticator(name: string) {
    const authenticator = this.#authenticators.get(name);

    assert(`No authenticator found for "${name}".`, authenticator !== undefined);

    return authenticator;
  }

  #getAuthenticatorFromStoreData(storeData: StoreData) {
    const { authenticator: authenticatorName } = storeData.authenticated ?? {};

    if (storeData.authenticated && authenticatorName) {
      const authenticator = this.#lookupAuthenticator(authenticatorName);

      return authenticator;
    }
  }

  async #restoreFromStore(storeData: StoreData) {
    const authenticator = this.#getAuthenticatorFromStoreData(storeData);

    try {
      const authenticatorData = await authenticator?.restore(storeData.authenticated?.data);

      await this.#handleAuthentication(authenticator as Authenticator, authenticatorData);
    } catch {
      await this.#handleInvalidation();
    }
  }

  // #region Handlers

  async #handleAuthentication(authenticator: Authenticator, data: AuthenticatorData) {
    this.authenticated = true;
    this.#authenticator = authenticator;
    this.#authenticatorData = data;

    await this.#updateStore();

    this.#subscribeToAuthenticator(this.#authenticator);
  }

  async #handleInvalidation() {
    if (this.#authenticator) {
      this.#unsubscribeToAuthenticator(this.#authenticator);
    }

    await this.#updateStore();

    this.authenticated = false;
    this.#authenticator = undefined;
    this.#authenticatorData = undefined;
  }

  // #region Public API

  async authenticate(authenticatorName: string, data: unknown) {
    try {
      const authenticator = this.#lookupAuthenticator(authenticatorName);
      const authenticatorData = await authenticator.authenticate(data);

      await this.#handleAuthentication(authenticator, authenticatorData);

      this.#publisher.notify('authenticationSucceeded', authenticatorData);
      // await this.#setup(authenticatorName, authenticatorData, true);
    } catch (error) {
      this.#publisher.notify('authenticationFailed', error);
      throw error;
    }
  }

  async invalidate(...args: unknown[]) {
    if (!this.authenticated) {
      return;
    }

    try {
      await this.#authenticator?.invalidate(this.#authenticatorData, ...args);
      await this.#handleInvalidation();

      this.#publisher.notify('invalidationSucceeded');
    } catch (error) {
      this.#publisher.notify('invalidationFailed', error);

      throw error;
    }
  }

  async restore() {
    const storeData = await this.#store.restore();

    await this.#restoreFromStore(storeData);
  }
}

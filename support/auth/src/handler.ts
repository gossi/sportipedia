import { tracked } from '@glimmer/tracking';
import { assert } from '@ember/debug';
import { registerDestructor } from '@ember/destroyable';

import EventManager, { type EventListener } from './-utils/event-manager.ts';
import LocalStorageStore from './session-stores/local-storage.ts';

import type { Authenticator } from './authenticators/authenticator.ts';
import type { AuthenticatorData, SessionStore, StoreData } from './session-stores/store.ts';

interface SessionHandlerEvents {
  authenticationSucceeded: [AuthenticatorData];
  invalidationSucceeded: [];
  sessionInvalidationFailed: [unknown];
}

export default class SessionHandler {
  #events = new EventManager<SessionHandlerEvents>();

  #store!: SessionStore;
  #storeData?: StoreData = undefined;

  #authenticators = new Map<string, Authenticator>();
  #authenticatorName?: string;
  #authenticatorData: AuthenticatorData = undefined;

  @tracked authenticated = false;

  constructore() {
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
    this.#store.on('sessionDataUpdated', this.#handleStoreDataUpdate);
  }

  #unregisterStore(store: SessionStore) {
    store.off('sessionDataUpdated', this.#handleStoreDataUpdate);
  }

  #handleStoreDataUpdate = async (data: StoreData) => {
    const { authenticator: authenticatorName } = data.authenticated ?? {};

    if (data.authenticated && authenticatorName) {
      const authenticator = this.#lookupAuthenticator(authenticatorName);

      try {
        const authenticatorData = await authenticator.restore(data.authenticated.content);

        this.#storeData = data;

        await this.#setup(authenticatorName, authenticatorData, true);
      } catch {
        await this.#clearWithStoreData(data, true);
      }
    } else {
      await this.#clearWithStoreData(data, true);
    }
  };

  #updateStore() {
    const data = this.#storeData;

    if (this.#authenticatorName) {
      if (this.#storeData?.authenticated) {
        this.#storeData.authenticated.authenticator = this.#authenticatorName;
      } else {
        this.#storeData = { authenticated: { authenticator: this.#authenticatorName } };
      }
    }

    return this.#store.persist(data as StoreData);
  }

  // #region Setup + Clear

  async #setup(authenticatorName: string, authenticatorData: AuthenticatorData, notify = false) {
    this.#authenticatorName = authenticatorName;
    // this.authenticated = true;
    this.#authenticatorData = authenticatorData;

    const trigger = notify && !this.authenticated;

    this.#bindToAuthenticatorEvents();

    try {
      await this.#updateStore();

      if (trigger) {
        this.trigger('authenticationSucceeded', authenticatorData);
      }
    } catch {
      this.authenticated = false;
      this.#authenticatorName = undefined;
      this.#authenticatorData = undefined;
    }
  }

  async #clearWithStoreData(data: StoreData, notify = false) {
    this.#storeData = data;

    await this.#clear(notify);
  }

  async #clear(notify = false) {
    const trigger = notify && this.authenticated;

    this.authenticated = false;
    this.#authenticatorName = undefined;
    this.#authenticatorData = undefined;

    await this.#updateStore();

    if (trigger) {
      this.trigger('invalidationSucceeded');
    }
  }

  // #region Authenticator

  #bindToAuthenticatorEvents() {
    const authenticator = this.#lookupAuthenticator(this.#authenticatorName as string);

    authenticator.on('sessionDataUpdated', this.#handleAuthenticatorSessionDataUpdated);
    authenticator.on('sessionDataInvalidated', this.#handleAuthenticatorSessionDataInvalidated);
  }

  #handleAuthenticatorSessionDataUpdated = async (data: AuthenticatorData) => {
    await this.#setup(this.#authenticatorName as string, data);
  };

  #handleAuthenticatorSessionDataInvalidated = async () => {
    await this.#clear(true);
  };

  registerAuthenticator(authenticator: Authenticator) {
    this.#authenticators.set(authenticator.name, authenticator);
  }

  #lookupAuthenticator(name: string) {
    const authenticator = this.#authenticators.get(name);

    assert(`No authenticator found for "${name}".`, authenticator !== undefined);

    return authenticator;
  }

  // #region Events

  on<E extends keyof SessionHandlerEvents>(event: E, cb: EventListener<SessionHandlerEvents, E>) {
    this.#events.addEventListener(event, cb);
  }

  off<E extends keyof SessionHandlerEvents>(event: E, cb: EventListener<SessionHandlerEvents, E>) {
    this.#events.removeEventListener(event, cb);
  }

  trigger<E extends keyof SessionHandlerEvents>(event: E, ...value: SessionHandlerEvents[E]) {
    this.#events.dispatchEvent(event, ...value);
  }

  // #region Public API

  async authenticate(authenticatorName: string, data: unknown) {
    const authenticator = this.#lookupAuthenticator(authenticatorName);

    try {
      const authenticatorData = await authenticator.authenticate(data);

      await this.#setup(authenticatorName, authenticatorData, true);
    } catch (error) {
      await this.#clear();
      throw error;
    }
  }

  async invalidate(...args: unknown[]) {
    if (!this.authenticated) {
      return;
    }

    const authenticator = this.#lookupAuthenticator(this.#authenticatorName as string);

    try {
      await authenticator.invalidate(this.#authenticatorData, ...args);

      authenticator.off('sessionDataUpdated', this.#handleAuthenticatorSessionDataUpdated);
      await this.#clear(true);
    } catch (error) {
      this.trigger('sessionInvalidationFailed', error);

      throw error;
    }
  }

  async restore() {
    try {
      const storeData = await this.#store.restore();

      const { authenticator: authenticatorName } = storeData.authenticated ?? {};

      if (storeData.authenticated && authenticatorName) {
        const authenticator = this.#lookupAuthenticator(authenticatorName);

        try {
          const authenticatorData = await authenticator.restore(storeData.authenticated.content);

          await this.#setup(authenticatorName, authenticatorData);
        } catch {
          await this.#clearWithStoreData(storeData);
        }
      }
    } catch {
      await this.#clear();
    }
  }
}

import { registerDestructor } from '@ember/destroyable';

import isEqual from '../-utils/equal.ts';
import BaseSessionStore from './base.ts';

import type { StoreData } from './store.ts';

/**
 * Session store that persists data in the browser's `localStorage`.
 */
export default class LocalStorageStore extends BaseSessionStore {
  /** The `localStorage` key the store persists data in. */
  key = 'auth-session';

  #lastData: StoreData | undefined = undefined;

  constructor() {
    super();

    globalThis.addEventListener('storage', this.#handleStorageEvent);

    registerDestructor(this, () =>
      globalThis.removeEventListener('storage', this.#handleStorageEvent)
    );
  }

  /**
   * Persists the `data` in the `localStorage`.
   *
   * @param data The data to persist
   * @returns A promise that resolves when the data has successfully been persisted and rejects otherwise.
   */
  persist(data: StoreData = {}) {
    this.#lastData = data;

    const stringifiedData = JSON.stringify(data);

    localStorage.setItem(this.key, stringifiedData);

    return Promise.resolve();
  }

  /**
   * Returns all data currently stored in the `localStorage` as a plain object.
   *
   * @returns A promise that resolves with the data currently persisted in the store when the data has been restored successfully and rejects otherwise.
   */
  restore(): Promise<StoreData> {
    const data = localStorage.getItem(this.key);

    return Promise.resolve(JSON.parse(data ?? '{}'));
  }

  /**
   * Clears the store by deleting the {@linkplain LocalStorageStore.key} from `localStorage`.
   *
   * @returns A promise that resolves when the store has been cleared successfully and rejects otherwise.
   */
  clear(): Promise<void> {
    localStorage.removeItem(this.key);
    this.#lastData = {};

    return Promise.resolve();
  }

  #handleStorageEvent = (e: StorageEvent) => {
    if (e.key === this.key) {
      void this.restore().then((data) => {
        if (!isEqual(data, this.#lastData)) {
          this.#lastData = data;
          this.trigger('sessionDataUpdated', data);
        }
      });
    }
  };
}

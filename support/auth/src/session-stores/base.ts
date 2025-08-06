import EventManager, { type EventListener } from '../-utils/event-manager.ts';

import type { SessionStore, StoreData, StoreEvents } from './store.ts';

/**
 * he base class for all session stores. __This serves as a starting point for
 * implementing custom session stores and must not be used directly.__
 *
 * Session Stores persist the session's state so that it survives a page reload
 * and is synchronized across multiple tabs or windows of the same application.
 */
export default abstract class BaseSessionStore implements SessionStore {
  #eventManager = new EventManager<StoreEvents>();

  /**
   * Persists the `data`. This replaces all currently stored data.
   *
   * @param args The data to persist
   * @returns A promise that resolves when the data has successfully been persisted and rejects otherwise.
   */
  abstract persist(...args: unknown[]): Promise<unknown>;

  /**
   * Returns all data currently stored as a plain object.
   *
   * @param args
   * @returns A promise that resolves with the data currently persisted in the store when the data has been restored successfully and rejects otherwise.
   */
  abstract restore(): Promise<StoreData>;

  /**
   * Clears the store.
   *
   * @param args
   * @returns A promise that resolves when the store has been cleared successfully and rejects otherwise.
   */
  abstract clear(...args: unknown[]): Promise<unknown>;

  on<E extends keyof StoreEvents>(event: E, cb: EventListener<StoreEvents, E>) {
    this.#eventManager.addEventListener(event, cb);
  }

  off<E extends keyof StoreEvents>(event: E, cb: EventListener<StoreEvents, E>) {
    this.#eventManager.removeEventListener(event, cb);
  }

  trigger<E extends keyof StoreEvents>(event: E, ...value: StoreEvents[E]) {
    this.#eventManager.dispatchEvent(event, ...value);
  }
}

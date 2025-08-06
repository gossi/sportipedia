type MaybePromise<T> = T | Promise<T>;

export type EventListener<
  Events extends Record<keyof Events, unknown[]>,
  Event extends keyof Events
> = (...data: Events[Event]) => MaybePromise<void>;

export default class EventManager<Events extends Record<keyof Events, unknown[]>> {
  #listeners = new Map<keyof Events, Set<EventListener<Events, keyof Events>>>();

  addEventListener<E extends keyof Events>(event: E, cb: EventListener<Events, E>) {
    const callbacks = this.#getCallbacksForEvent(event);

    callbacks.add(cb);
  }

  removeEventListener<E extends keyof Events>(event: E, cb: EventListener<Events, E>) {
    const callbacks = this.#getCallbacksForEvent(event);

    callbacks.delete(cb);
  }

  dispatchEvent<E extends keyof Events>(event: E, ...data: Events[E]): void {
    const callbacks = this.#getCallbacksForEvent(event);

    for (const cb of callbacks) {
      void cb(...data);
    }
  }

  #getCallbacksForEvent<E extends keyof Events>(event: E) {
    if (!this.#listeners.has(event)) {
      this.#listeners.set(event, new Set());
    }

    return this.#listeners.get(event) as Set<EventListener<Events, E>>;
  }
}

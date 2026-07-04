import type { ReactiveResource } from '@warp-drive/core/reactive';

export function asReactiveResource<T>(record: T): ReactiveResource & T {
  return record as ReactiveResource & T;
}

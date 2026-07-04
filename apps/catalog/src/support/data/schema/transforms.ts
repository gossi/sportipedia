import { Type } from '@warp-drive/core/types/symbols';

import type { Transformation } from '@warp-drive/core/reactive';

export const TemporalDateTimeTransform: Transformation<string, Temporal.PlainDateTime> = {
  hydrate: (value: string): Temporal.PlainDateTime => Temporal.PlainDateTime.from(value),

  serialize: (value: Temporal.PlainDateTime): string => value.toString(),

  [Type]: 'datetime'
};

export const TemporalDateTransform: Transformation<string, Temporal.PlainDate> = {
  hydrate: (value: string): Temporal.PlainDate => Temporal.PlainDate.from(value),

  serialize: (value: Temporal.PlainDate): string => value.toString(),

  [Type]: 'date'
};

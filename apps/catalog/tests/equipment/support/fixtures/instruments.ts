import { Type } from '@warp-drive/core/types/symbols';

import type { Instrument } from '#equipment';

export const UNICYCLE: Instrument = Object.freeze({
  [Type]: 'instrument',
  id: 'unicycle',
  title: 'Unicycle',
  slug: 'unicycle',
  description: 'Best vehicle in the world',
  createdAt: Temporal.Now.plainDateTimeISO(),
  updatedAt: Temporal.Now.plainDateTimeISO()
});

export const SKATEBOARD: Instrument = Object.freeze({
  [Type]: 'instrument',
  id: 'skateboard',
  title: 'Skateboard',
  slug: 'skateboard',
  description: 'For the streets',
  createdAt: Temporal.Now.plainDateTimeISO(),
  updatedAt: Temporal.Now.plainDateTimeISO()
});

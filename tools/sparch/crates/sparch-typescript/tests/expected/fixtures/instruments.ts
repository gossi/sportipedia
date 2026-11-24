import { Type } from '@warp-drive/core/types/symbols';

import type { Instrument } from '#equipment';
import type { ID, Slug } from '#/support/domain-objects/fields';

export const UNICYCLE: Instrument = Object.freeze({
  [Type]: 'instrument',
  id: 'equipment:instrument:unicycle',
  title: 'Unicycle',
  slug: 'unicycle',
  description: 'Best vehicle in the world',
  createdAt: Temporal.Now.plainDateTimeISO(),
  updatedAt: Temporal.Now.plainDateTimeISO()
});

export const SKATEBOARD: Instrument = Object.freeze({
  [Type]: 'instrument',
  id: 'equipment:instrument:skateboard',
  title: 'Skateboard',
  slug: 'skateboard',
  description: 'For the streets',
  createdAt: Temporal.Now.plainDateTimeISO(),
  updatedAt: Temporal.Now.plainDateTimeISO()
});


export const INSTRUMENTS = [
  UNICYCLE,
  SKATEBOARD
];

export function findInstrumentById(
  id: ID,
  instruments: Instrument[] = INSTRUMENTS
): Instrument | undefined {
  return instruments.find((i) => i.id === id);
}

export function findInstrumentBySlug(
  slug: Slug,
  instruments: Instrument[] = INSTRUMENTS
): Instrument | undefined {
  return instruments.find((i) => i.slug === slug);
}

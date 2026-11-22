import { Type } from '@warp-drive/core/types/symbols';

import type { Apparatus } from '#equipment';
import type { ID, Slug } from '#/support/domain-objects/fields';

export const PARALLEL_BARS: Apparatus = Object.freeze({
  [Type]: 'apparatus',
  id: 'equipment:apparatus:parallel-bars',
  title: 'Parallel Bars',
  slug: 'parallel-bars',
  description: 'The apparatus consists of two parallel bars that are held parallel to, and elevated above, the floor by a metal supporting framework.',
  createdAt: Temporal.Now.plainDateTimeISO(),
  updatedAt: Temporal.Now.plainDateTimeISO()
});

export const BALANCE_BEAM: Apparatus = Object.freeze({
  [Type]: 'apparatus',
  id: 'equipment:apparatus:balance-beam',
  title: 'Balance Beam',
  slug: 'balance-beam',
  description: 'The beam is a small, thin beam that is typically raised from the floor on a leg or stand at both ends. It is usually covered with leather-like material and is only four inches wide.',
  createdAt: Temporal.Now.plainDateTimeISO(),
  updatedAt: Temporal.Now.plainDateTimeISO()
});

export const STILL_RINGS: Apparatus = Object.freeze({
  [Type]: 'apparatus',
  id: 'equipment:apparatus:still-rings',
  title: 'Still Rings',
  slug: 'still-rings',
  description: 'The apparatus consists of two rings that hang freely from a rigid metal frame. Each ring is supported by a strap, which connects to a steel cable suspended from the metal frame.',
  createdAt: Temporal.Now.plainDateTimeISO(),
  updatedAt: Temporal.Now.plainDateTimeISO()
});

export const HORIZONTAL_BAR: Apparatus = Object.freeze({
  [Type]: 'apparatus',
  id: 'equipment:apparatus:horizontal-bar',
  title: 'Horizontal Bar',
  slug: 'horizontal-bar',
  description: 'The Horizontal Bar is an apparatus consisting of a single elevated horizontal bar, on which athletes perform dynamic swinging, turning and flight elements using a variety of hand grips.',
  createdAt: Temporal.Now.plainDateTimeISO(),
  updatedAt: Temporal.Now.plainDateTimeISO()
});


export const APPARATUSES = [
  PARALLEL_BARS,
  BALANCE_BEAM,
  STILL_RINGS,
  HORIZONTAL_BAR
];

export function findApparatusById(
  id: ID,
  apparatuses: Apparatus[] = APPARATUSES
): Apparatus | undefined {
  return apparatuses.find((i) => i.id === id);
}

export function findApparatusBySlug(
  slug: Slug,
  apparatuses: Apparatus[] = APPARATUSES
): Apparatus | undefined {
  return apparatuses.find((i) => i.slug === slug);
}

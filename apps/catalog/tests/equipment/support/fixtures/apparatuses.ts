import { Type } from '@warp-drive/core/types/symbols';

import type { Apparatus } from '#equipment';

export const PARALLEL_BARS: Apparatus = Object.freeze({
  [Type]: 'apparatus',
  id: 'parallel-bars',
  title: 'Parallel Bars',
  slug: 'parallel-bars',
  description:
    'The apparatus consists of two parallel bars that are held parallel to, and elevated above, the floor by a metal supporting framework.',
  createdAt: Temporal.Now.plainDateTimeISO(),
  updatedAt: Temporal.Now.plainDateTimeISO()
});

export const BALANCE_BEAM: Apparatus = Object.freeze({
  [Type]: 'apparatus',
  id: 'balance-beam',
  title: 'Balance Beam',
  slug: 'balance-beam',
  description:
    'The beam is a small, thin beam that is typically raised from the floor on a leg or stand at both ends. It is usually covered with leather-like material and is only four inches wide.',
  createdAt: Temporal.Now.plainDateTimeISO(),
  updatedAt: Temporal.Now.plainDateTimeISO()
});

export const RINGS: Apparatus = Object.freeze({
  [Type]: 'apparatus',
  id: 'rings',
  title: 'Rings',
  slug: 'rings',
  description:
    'The apparatus consists of two rings that hang freely from a rigid metal frame. Each ring is supported by a strap, which connects to a steel cable suspended from the metal frame.',
  createdAt: Temporal.Now.plainDateTimeISO(),
  updatedAt: Temporal.Now.plainDateTimeISO()
});

export const APPARATUSES = [PARALLEL_BARS, BALANCE_BEAM, RINGS];

export function findApparatusById(
  id: string,
  apparatuses: Apparatus[] = APPARATUSES
): Apparatus | undefined {
  return apparatuses.find((i) => i.id === id);
}

export function findApparatusBySlug(
  slug: string,
  apparatuses: Apparatus[] = APPARATUSES
): Apparatus | undefined {
  return apparatuses.find((i) => i.slug === slug);
}

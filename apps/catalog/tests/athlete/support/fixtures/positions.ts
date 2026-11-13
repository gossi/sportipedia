import { Type } from '@warp-drive/core/types/symbols';

import { HORIZONTAL_BAR, UNICYCLE } from '#equipment-test-support';

import type { Position } from '#athlete';

export const UNICYCLE_RIDING: Position = Object.freeze({
  [Type]: 'position',
  id: 'athlete:position:unicycle-riding',
  title: 'Riding',
  rawSlug: 'riding',
  slug: 'unicycle/riding',
  description: 'Riding on a unicycle',
  instrument: UNICYCLE,
  createdAt: Temporal.Now.plainDateTimeISO(),
  updatedAt: Temporal.Now.plainDateTimeISO()
});

export const UNICYCLE_ON_TIRE: Position = Object.freeze({
  [Type]: 'position',
  id: 'athlete:position:unicycle-on-tire',
  title: 'On Tire',
  rawSlug: 'on-tire',
  slug: 'unicycle/on-tire',
  description: 'Feet are on the tire',
  instrument: UNICYCLE,
  createdAt: Temporal.Now.plainDateTimeISO(),
  updatedAt: Temporal.Now.plainDateTimeISO()
});

export const UNICYCLE_SEAT_IN_FRONT: Position = Object.freeze({
  [Type]: 'position',
  id: 'athlete:position:unicycle-seat-in-front',
  title: 'Seat in-front',
  rawSlug: 'seat-in-front',
  slug: 'unicycle/seat-in-front',
  description: 'Seat is hold in front of the body',
  instrument: UNICYCLE,
  createdAt: Temporal.Now.plainDateTimeISO(),
  updatedAt: Temporal.Now.plainDateTimeISO()
});

export const GYMNASTICS_STRAIGHT_ARM_SUPPORT: Position = Object.freeze({
  [Type]: 'position',
  id: 'athlete:position:gymnastics-straight-arm-support',
  title: 'Straight-arm support',
  rawSlug: 'straight-arm-support',
  slug: 'horizontal-bar/straight-arm-support',
  description: 'Athlete has their arms straight while supporting themselves onto the bar',
  apparatus: HORIZONTAL_BAR,
  createdAt: Temporal.Now.plainDateTimeISO(),
  updatedAt: Temporal.Now.plainDateTimeISO()
});

export const GYMNASTICS_LONG_HANG: Position = Object.freeze({
  [Type]: 'position',
  id: 'athlete:position:gymnastics-long-hang',
  title: 'Long Hang',
  rawSlug: 'long-hang',
  slug: 'horizontal-bar/long-hang',
  description: 'Athlete has their arms straight while hanging on the bar',
  apparatus: HORIZONTAL_BAR,
  createdAt: Temporal.Now.plainDateTimeISO(),
  updatedAt: Temporal.Now.plainDateTimeISO()
});

export const READY_STANCE: Position = Object.freeze({
  [Type]: 'position',
  id: 'athlete:position:ready-stance',
  title: 'Ready Stance',
  rawSlug: 'ready-stance',
  slug: 'ready-stance',
  description: 'Athletic stance with knees slightly bent',
  createdAt: Temporal.Now.plainDateTimeISO(),
  updatedAt: Temporal.Now.plainDateTimeISO()
});

export const POSITIONS = [
  UNICYCLE_RIDING,
  UNICYCLE_ON_TIRE,
  UNICYCLE_SEAT_IN_FRONT,
  GYMNASTICS_STRAIGHT_ARM_SUPPORT,
  GYMNASTICS_LONG_HANG,
  READY_STANCE
];

export function findPositionById(
  id: string,
  positions: Position[] = POSITIONS
): Position | undefined {
  return positions.find((i) => i.id === id);
}

export function findPositionBySlug(
  slug: string,
  positions: Position[] = POSITIONS
): Position | undefined {
  return positions.find((i) => i.slug === slug);
}

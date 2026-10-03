/**
 * @module Equipment
 * @category Domain Objects
 */
import { asReactiveResource } from '#support/data';

import type { Apparatus } from './apparatus/apparatus';
import type { Instrument } from './instrument/instrument';

/**
 * @group Equipment
 * @category Equipment
 */
export type Equipment = Apparatus | Instrument;

const MAP = {
  instrument: 'instrument',
  instruments: 'instrument',
  apparatus: 'apparatus',
  apparatuses: 'apparatus'
};

/**
 * @group Equipment
 * @category Equipment
 */
export function getType(equipment: Equipment & { $type?: string }): string | undefined {
  // eslint-disable-next-line unicorn/prefer-early-return
  if (Object.hasOwn(equipment, '$type')) {
    const type = equipment.$type as 'instrument' | 'instruments' | 'apparatus' | 'apparatuses';

    return MAP[type];
  }
}

/** @internal */
export const asReactiveApparatusResource = asReactiveResource<Apparatus>;
/** @internal */
export const asReactiveInstrumentResource = asReactiveResource<Instrument>;

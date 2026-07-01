import type { Apparatus } from './apparatus/apparatus';
import type { Instrument } from './instrument/instrument';

export type Equipment = Apparatus | Instrument;

const MAP = {
  instrument: 'instrument',
  instruments: 'instrument',
  apparatus: 'apparatus',
  apparatuses: 'apparatus'
};

export function getType(equipment: Equipment & { $type?: string }): string | undefined {
  // eslint-disable-next-line unicorn/prefer-early-return
  if (Object.hasOwn(equipment, '$type')) {
    const type = equipment.$type as 'instrument' | 'instruments' | 'apparatus' | 'apparatuses';

    return MAP[type];
  }
}

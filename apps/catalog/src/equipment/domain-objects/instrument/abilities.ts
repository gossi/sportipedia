/**
 * @module Instrument Abilities
 * @mergeModuleWith Instrument
 */
import type { Instrument } from './instrument';
import type { User } from '@sportipedia/user';

/**
 * @group Instrument
 * @category Abilities
 * @source
 */
export function canCatalogInstrument(user?: User) {
  return user?.role === 'user' || user?.role === 'admin';
}

/**
 * @group Instrument
 * @category Abilities
 * @source
 */
export function canEditInstrument(_instrument: Instrument, user?: User) {
  return user?.role === 'user' || user?.role === 'admin';
}

/**
 * @group Instrument
 * @category Abilities
 * @source
 */
export function canArchiveInstrument(_instrument: Instrument, user?: User) {
  return user?.role === 'admin';
}

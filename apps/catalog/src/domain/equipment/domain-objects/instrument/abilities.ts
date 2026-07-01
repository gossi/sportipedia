import type { Instrument } from './instrument';
import type { User } from '@sportipedia/user';

export function canCatalogInstrument(user?: User) {
  return user?.role === 'user' || user?.role === 'admin';
}

export function canEditInstrument(_instrument: Instrument, user?: User) {
  return user?.role === 'user' || user?.role === 'admin';
}

export function canArchiveInstrument(_instrument: Instrument, user?: User) {
  return user?.role === 'admin';
}

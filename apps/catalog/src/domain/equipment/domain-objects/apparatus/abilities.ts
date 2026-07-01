import type { Apparatus } from './apparatus';
import type { User } from '@sportipedia/user';

export function canCatalogApparatus(user?: User) {
  return user?.role === 'user' || user?.role === 'admin';
}

export function canEditApparatus(_apparatus: Apparatus, user?: User) {
  return user?.role === 'user' || user?.role === 'admin';
}

export function canArchiveApparatus(_apparatus: Apparatus, user?: User) {
  return user?.role === 'admin';
}

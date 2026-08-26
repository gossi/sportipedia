/**
 * @module Apparatus Abilities
 * @mergeModuleWith Apparatus
 */
import type { Apparatus } from './apparatus';
import type { User } from '@sportipedia/user';

/**
 * @group Apparatus
 * @category Abilities
 * @source
 */
export function canCatalogApparatus(user?: User) {
  return user?.role === 'user' || user?.role === 'admin';
}

/**
 * @group Apparatus
 * @category Abilities
 * @source
 */
export function canEditApparatus(_apparatus: Apparatus, user?: User) {
  return user?.role === 'user' || user?.role === 'admin';
}

/**
 * @group Apparatus
 * @category Abilities
 * @source
 */
export function canArchiveApparatus(_apparatus: Apparatus, user?: User) {
  return user?.role === 'admin';
}

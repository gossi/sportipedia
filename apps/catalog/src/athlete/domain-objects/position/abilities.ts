/**
 * @module Position Abilities
 * @mergeModuleWith Position
 */
import type { Position } from './position';
import type { User } from '@sportipedia/user';

/**
 * @group Position
 * @category Abilities
 * @source
 */
export function canCatalogPosition(user?: User) {
  return user?.role === 'user' || user?.role === 'admin';
}

/**
 * @group Position
 * @category Abilities
 * @source
 */
export function canEditPosition(_position: Position, user?: User) {
  return user?.role === 'user' || user?.role === 'admin';
}

/**
 * @group Position
 * @category Abilities
 * @source
 */
export function canArchivePosition(_position: Position, user?: User) {
  return user?.role === 'admin';
}

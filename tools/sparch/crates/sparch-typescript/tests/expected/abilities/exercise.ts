/**
 * @module Exercise Abilities
 * @mergeModuleWith Exercise
 */

import type { Exercise } from './exercise';
import type { User } from '@sportipedia/user';

/**
 * @group Exercise
 * @category Abilities
 * @source
 */
export function canCreateExercise(user?: User) {
  return user?.role === 'user' || user?.role === 'admin';
}


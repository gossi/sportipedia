/**
 * @module Widget Abilities
 * @mergeModuleWith Widget
 */

import type { Widget } from './widget';
import type { User } from '@sportipedia/user';

/**
 * @group Widget
 * @category Abilities
 * @source
 */
export function canArchiveWidget(_widget: Widget, user?: User) {
  return user?.role === 'user' || user?.role === 'admin';
}

/**
 * @group Widget
 * @category Abilities
 * @source
 */
export function canCreateWidget(user?: User) {
  return user?.role === 'user' || user?.role === 'admin';
}

/**
 * @group Widget
 * @category Abilities
 * @source
 */
export function canEditWidget(_widget: Widget, user?: User) {
  return user?.role === 'user' || user?.role === 'admin';
}

/**
 * @group Widget
 * @category Abilities
 * @source
 */
export function canNoteWidget(_widget: Widget, user?: User) {
  return user?.role === 'user' || user?.role === 'admin';
}

/**
 * @group Widget
 * @category Abilities
 * @source
 */
export function canRelabelWidget(_widget: Widget, user?: User) {
  return user?.role === 'user' || user?.role === 'admin';
}


/**
 * @module ExerciseTag
 * @category Domain Objects
 */

import type { Type } from '@warp-drive/core/types/symbols';
import type { Mutable } from '@warp-drive/core/types/utils';
import type { ID } from '#/support/domain-objects/fields';
import type { Timestamps } from '#/support/domain-objects/timestamps';
import type { Tag } from '#equipment';
import type { Exercise } from '#exercises';

/**
 * @group ExerciseTag
 * @category Domain Object
 */
export interface ExerciseTag extends Timestamps {
  /** @internal */
  readonly [Type]: 'exercise-tag';

  readonly id: ID;
  readonly weight: number;

  readonly exercise: Exercise;
  readonly tag: Tag;
}

export type ExerciseTagFields = Mutable<Pick<ExerciseTag, 'exercise' | 'tag' | 'weight'>>;

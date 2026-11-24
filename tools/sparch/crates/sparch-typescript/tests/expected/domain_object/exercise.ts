/**
 * @module Exercise
 * @category Domain Objects
 */

import type { Type } from '@warp-drive/core/types/symbols';
import type { Mutable } from '@warp-drive/core/types/utils';
import type { ID } from '#/support/domain-objects/fields';
import type { Timestamps } from '#/support/domain-objects/timestamps';
import type { Apparatus, Tag } from '#equipment';

/**
 * @group Exercise
 * @category Domain Object
 */
export interface Exercise extends Timestamps {
  /** @internal */
  readonly [Type]: 'exercise';

  readonly id: ID;
  readonly title: string;
  readonly difficulty?: number;

  readonly primaryApparatus?: Apparatus;
  readonly safetyApparatus?: Apparatus;
  readonly tags?: Tag[];
}

export type ExerciseFields = Mutable<Pick<Exercise, 'title' | 'difficulty' | 'primaryApparatus' | 'safetyApparatus' | 'tags'>>;

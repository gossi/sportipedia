/**
 * @module Tag
 * @category Domain Objects
 */

import type { Type } from '@warp-drive/core/types/symbols';
import type { Mutable } from '@warp-drive/core/types/utils';
import type { ID } from '#/support/domain-objects/fields';
import type { Timestamps } from '#/support/domain-objects/timestamps';
import type { Apparatus } from '#equipment';
import type { Exercise } from '#exercises';

/**
 * @group Tag
 * @category Domain Object
 */
export interface Tag extends Timestamps {
  /** @internal */
  readonly [Type]: 'tag';

  readonly id: ID;
  readonly title: string;

  readonly apparatuses?: Apparatus[];
  readonly exercises?: Exercise[];
}

export type TagFields = Mutable<Pick<Tag, 'title' | 'apparatuses' | 'exercises'>>;

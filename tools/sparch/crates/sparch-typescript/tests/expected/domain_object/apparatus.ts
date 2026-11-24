/**
 * @module Apparatus
 * @category Domain Objects
 */

import type { Type } from '@warp-drive/core/types/symbols';
import type { Mutable } from '@warp-drive/core/types/utils';
import type { ID, Slug } from '#/support/domain-objects/fields';
import type { Timestamps } from '#/support/domain-objects/timestamps';
import type { Position } from '#athlete';
import type { ApparatusCertification, Tag } from '#equipment';

/**
 * @group Apparatus
 * @category Domain Object
 */
export interface Apparatus extends Timestamps {
  /** @internal */
  readonly [Type]: 'apparatus';

  readonly id: ID;
  readonly title: string;
  readonly slug: Slug;
  readonly description?: string;

  readonly certification?: ApparatusCertification;
  readonly positions?: Position[];
  readonly tags?: Tag[];
}

export type ApparatusFields = Mutable<Pick<Apparatus, 'title' | 'slug' | 'certification' | 'description' | 'positions' | 'tags'>>;

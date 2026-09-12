/**
 * @module Apparatus
 * @category Domain Objects
 */
import type { Type } from '@warp-drive/core/types/symbols';
import type { ID, Slug } from '#/support/domain-objects/fields';
import type { Timestamps } from '#/support/domain-objects/timestamps';

/**
 * @group Apparatus
 * @category Domain Object
 */
export interface Apparatus extends Timestamps {
  /** @internal */
  [Type]: 'apparatus';

  id: ID;
  title: string;
  description?: string;
  slug: Slug;
}

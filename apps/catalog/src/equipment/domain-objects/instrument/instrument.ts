/**
 * @module Instrument
 * @category Domain Objects
 */
import type { Type } from '@warp-drive/core/types/symbols';
import type { ID, Slug } from '#/support/domain-objects/fields';
import type { Timestamps } from '#/support/domain-objects/timestamps';

/**
 * @group Instrument
 * @category Domain Object
 */
export interface Instrument extends Timestamps {
  [Type]: 'instrument';

  id: ID;
  title: string;
  description?: string;
  slug: Slug;
}

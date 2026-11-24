/**
 * @module Instrument
 * @category Domain Objects
 */

import type { Type } from '@warp-drive/core/types/symbols';
import type { Mutable } from '@warp-drive/core/types/utils';
import type { ID, Slug } from '#/support/domain-objects/fields';
import type { Timestamps } from '#/support/domain-objects/timestamps';

/**
 * @group Instrument
 * @category Domain Object
 */
export interface Instrument extends Timestamps {
  /** @internal */
  readonly [Type]: 'instrument';

  readonly id: ID;
  readonly title: string;
  readonly slug: Slug;
  readonly description?: string;
}

export type InstrumentFields = Mutable<Pick<Instrument, 'title' | 'slug' | 'description'>>;

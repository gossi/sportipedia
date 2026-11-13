/**
 * @module Position
 * @category Domain Objects
 */
import type { Type } from '@warp-drive/core/types/symbols';
import type { Mutable } from '@warp-drive/core/types/utils';
import type { ID, Slug } from '#/support/domain-objects/fields';
import type { Timestamps } from '#/support/domain-objects/timestamps';
import type { Apparatus, Instrument } from '#equipment';

/**
 * @group Position
 * @category Domain Object
 */
export interface Position extends Timestamps {
  /** @internal */
  readonly [Type]: 'position';

  readonly id: ID;
  readonly title: string;
  readonly description?: string;
  readonly slug: Slug;
  readonly rawSlug: Slug;

  readonly apparatus?: Apparatus;
  readonly instrument?: Instrument;
}

export type PositionFields = Mutable<Pick<Position, 'title' | 'description' | 'slug'>>;

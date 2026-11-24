/**
 * @module Widget
 * @category Domain Objects
 */

import type { Type } from '@warp-drive/core/types/symbols';
import type { Mutable } from '@warp-drive/core/types/utils';
import type { ID, Slug } from '#/support/domain-objects/fields';
import type { Timestamps } from '#/support/domain-objects/timestamps';

/**
 * @group Widget
 * @category Domain Object
 */
export interface Widget extends Timestamps {
  /** @internal */
  readonly [Type]: 'widget';

  readonly id: ID;
  readonly title: string;
  readonly slug: Slug;
  readonly archivedAt?: string;
  readonly coachId?: string;
  readonly description?: string;
  readonly label?: string;
  readonly teamId?: string;
}

export type WidgetFields = Mutable<Pick<Widget, 'title' | 'slug' | 'archivedAt' | 'coachId' | 'description' | 'label' | 'teamId'>>;

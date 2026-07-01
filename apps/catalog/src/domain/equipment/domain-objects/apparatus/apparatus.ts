import type { Type } from '@warp-drive/core/types/symbols';
import type { ID, Slug } from '#/support/domain-objects/fields';
import type { Timestamps } from '#/support/domain-objects/timestamps';

export interface Apparatus extends Timestamps {
  [Type]: 'apparatuses';

  id: ID;
  title: string;
  description?: string;
  slug: Slug;
}

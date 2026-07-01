import type { Type } from '@warp-drive/core/types/symbols';
import type { ID, Slug } from '#/support/domain-objects/fields';
import type { Timestamps } from '#/support/domain-objects/timestamps';

export interface Instrument extends Timestamps {
  [Type]: 'instruments';

  id: ID;
  title: string;
  description?: string;
  slug: Slug;
}

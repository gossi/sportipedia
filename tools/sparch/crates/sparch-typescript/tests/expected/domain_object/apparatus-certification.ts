/**
 * @module ApparatusCertification
 * @category Domain Objects
 */

import type { Type } from '@warp-drive/core/types/symbols';
import type { Mutable } from '@warp-drive/core/types/utils';
import type { ID } from '#/support/domain-objects/fields';
import type { Timestamps } from '#/support/domain-objects/timestamps';
import type { Apparatus } from '#equipment';

/**
 * @group ApparatusCertification
 * @category Domain Object
 */
export interface ApparatusCertification extends Timestamps {
  /** @internal */
  readonly [Type]: 'apparatus-certification';

  readonly id: ID;
  readonly level: string;

  readonly apparatus: Apparatus;
}

export type ApparatusCertificationFields = Mutable<Pick<ApparatusCertification, 'apparatus' | 'level'>>;

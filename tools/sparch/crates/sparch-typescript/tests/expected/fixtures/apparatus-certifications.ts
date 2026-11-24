import { Type } from '@warp-drive/core/types/symbols';

import { STILL_RINGS } from '#equipment-test-support';

import type { ApparatusCertification } from '#equipment';
import type { ID } from '#/support/domain-objects/fields';

export const STILL_RINGS_EN16634: ApparatusCertification = Object.freeze({
  [Type]: 'apparatus-certification',
  id: 'equipment:apparatus-certification:still-rings-en16634',
  apparatus: STILL_RINGS,
  level: 'EN 16634 Class A',
  createdAt: Temporal.Now.plainDateTimeISO(),
  updatedAt: Temporal.Now.plainDateTimeISO()
});


export const APPARATUS_CERTIFICATIONS = [
  STILL_RINGS_EN16634
];

export function findApparatusCertificationById(
  id: ID,
  apparatusCertifications: ApparatusCertification[] = APPARATUS_CERTIFICATIONS
): ApparatusCertification | undefined {
  return apparatusCertifications.find((i) => i.id === id);
}

import { APPARATUSES } from './apparatuses';
import { INSTRUMENTS } from './instruments';

import type { Equipment } from '#/equipment/domain-objects/equipment';

export const EQUIPMENTS = [...INSTRUMENTS, ...APPARATUSES];

export function findEquipmentById(
  id: string,
  equipments: Equipment[] = APPARATUSES
): Equipment | undefined {
  return equipments.find((i) => i.id === id);
}

export function findEquipmentBySlug(
  slug: string,
  equipments: Equipment[] = APPARATUSES
): Equipment | undefined {
  return equipments.find((i) => i.slug === slug);
}

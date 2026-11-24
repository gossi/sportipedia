import { Type } from '@warp-drive/core/types/symbols';

import type { Tag } from '#equipment';
import type { ID } from '#/support/domain-objects/fields';

export const GRIP: Tag = Object.freeze({
  [Type]: 'tag',
  id: 'equipment:tag:grip',
  title: 'Grip',
  createdAt: Temporal.Now.plainDateTimeISO(),
  updatedAt: Temporal.Now.plainDateTimeISO()
});

export const SUPPORT: Tag = Object.freeze({
  [Type]: 'tag',
  id: 'equipment:tag:support',
  title: 'Support',
  createdAt: Temporal.Now.plainDateTimeISO(),
  updatedAt: Temporal.Now.plainDateTimeISO()
});


export const TAGS = [
  GRIP,
  SUPPORT
];

export function findTagById(
  id: ID,
  tags: Tag[] = TAGS
): Tag | undefined {
  return tags.find((i) => i.id === id);
}

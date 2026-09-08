import { Type } from '@warp-drive/core/types/symbols';

import type { ID } from '#/support/domain-objects/fields';
import type { Timestamps } from '#/support/domain-objects/timestamps';

type AsStrings<Type> = {
  [Property in keyof Type]: string;
};

interface Data extends Partial<Timestamps> {
  [Type]: string;
  id?: ID;
}

function parseTimestamps(data: Data) {
  const chronos: Partial<AsStrings<Timestamps>> = {};

  if (data.createdAt) {
    chronos.createdAt = data.createdAt.toString();
  }

  if (data.updatedAt) {
    chronos.updatedAt = data.updatedAt.toString();
  }

  return chronos;
}

function filterAttributes(data: Record<string, unknown>, attributes: string[]) {
  return Object.fromEntries(Object.entries(data).filter(([k, _v]) => !attributes.includes(k)));
}

export function toResource(data: Data, id?: string) {
  return {
    type: data[Type],
    id: id ?? (Object.hasOwn(data, 'id') ? data.id : ''),
    attributes: filterAttributes(
      {
        ...data,
        ...parseTimestamps(data)
      },
      ['id']
    )
  };
}

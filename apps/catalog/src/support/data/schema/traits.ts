import type { PolarisTrait } from '@warp-drive/core/types/schema/fields';

export const Timestamps: PolarisTrait = {
  name: 'timestamps',
  mode: 'polaris',
  fields: [
    { name: 'createdAt', kind: 'field', type: 'date' },
    { name: 'updatedAt', kind: 'field', type: 'date' }
  ]
};

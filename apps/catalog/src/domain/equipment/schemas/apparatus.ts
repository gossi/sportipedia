import { withDefaults } from '@warp-drive/core/reactive';

export const apparatusSchema = withDefaults({
  type: 'apparatuses',
  // identity: { kind: '@id', name: 'id' },
  fields: [
    { kind: 'field', name: 'title' },
    { kind: 'field', name: 'description' },
    { kind: 'field', name: 'slug' }
  ]
});

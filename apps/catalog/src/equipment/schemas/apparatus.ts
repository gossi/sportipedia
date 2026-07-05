import { withDefaults } from '@warp-drive/core/reactive';

export const apparatusSchema = withDefaults({
  type: 'apparatus',
  // identity: { kind: '@id', name: 'id' },
  fields: [
    { kind: 'field', name: 'title' },
    { kind: 'field', name: 'description' },
    { kind: 'field', name: 'slug' }
  ],
  traits: ['timestamps']
});

import { withDefaults } from '@warp-drive/legacy/model/migration-support';

export const tagSchema = withDefaults({
  type: 'tag',
  fields: [
    { kind: 'attribute', name: 'title' },
    {
      kind: 'hasMany',
      name: 'apparatuses',
      type: 'apparatus',
      options: { async: false, inverse: 'tags' }
    },
    {
      kind: 'hasMany',
      name: 'exercises',
      type: 'exercise',
      options: { async: false, inverse: 'tags' }
    },
  ],
  traits: ['timestamps']
});

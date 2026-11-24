import { withDefaults } from '@warp-drive/legacy/model/migration-support';

export const apparatusSchema = withDefaults({
  type: 'apparatus',
  fields: [
    { kind: 'attribute', name: 'title' },
    { kind: 'attribute', name: 'description' },
    {
      kind: 'belongsTo',
      name: 'certification',
      type: 'apparatus-certification',
      options: { async: false, inverse: 'apparatus' }
    },
    {
      kind: 'hasMany',
      name: 'positions',
      type: 'position',
      options: { async: false, inverse: 'apparatus' }
    },
    {
      kind: 'hasMany',
      name: 'tags',
      type: 'tag',
      options: { async: false, inverse: 'apparatuses' }
    },
  ],
  traits: ['timestamps']
});

import { withDefaults } from '@warp-drive/legacy/model/migration-support';

export const exerciseSchema = withDefaults({
  type: 'exercise',
  fields: [
    { kind: 'attribute', name: 'title' },
    { kind: 'attribute', name: 'difficulty' },
    {
      kind: 'belongsTo',
      name: 'primaryApparatus',
      type: 'apparatus',
      // eslint-disable-next-line unicorn/no-null -- WarpDrive requires an explicit null inverse to mark the relationship unidirectional
      options: { async: false, inverse: null }
    },
    {
      kind: 'belongsTo',
      name: 'safetyApparatus',
      type: 'apparatus',
      // eslint-disable-next-line unicorn/no-null -- WarpDrive requires an explicit null inverse to mark the relationship unidirectional
      options: { async: false, inverse: null }
    },
    {
      kind: 'hasMany',
      name: 'tags',
      type: 'tag',
      options: { async: false, inverse: 'exercises' }
    },
  ],
  traits: ['timestamps']
});

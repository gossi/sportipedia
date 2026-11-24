import { withDefaults } from '@warp-drive/legacy/model/migration-support';

export const exerciseTagSchema = withDefaults({
  type: 'exercise-tag',
  fields: [
    { kind: 'attribute', name: 'weight' },
    {
      kind: 'belongsTo',
      name: 'exercise',
      type: 'exercise',
      // eslint-disable-next-line unicorn/no-null -- WarpDrive requires an explicit null inverse to mark the relationship unidirectional
      options: { async: false, inverse: null }
    },
    {
      kind: 'belongsTo',
      name: 'tag',
      type: 'tag',
      // eslint-disable-next-line unicorn/no-null -- WarpDrive requires an explicit null inverse to mark the relationship unidirectional
      options: { async: false, inverse: null }
    },
  ],
  traits: ['timestamps']
});

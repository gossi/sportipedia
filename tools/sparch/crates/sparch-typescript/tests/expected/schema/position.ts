import { withDefaults } from '@warp-drive/legacy/model/migration-support';

export const positionSchema = withDefaults({
  type: 'position',
  fields: [
    { kind: 'attribute', name: 'title' },
    { kind: 'attribute', name: 'rawSlug' },
    { kind: 'attribute', name: 'description' },
    {
      kind: 'belongsTo',
      name: 'apparatus',
      type: 'apparatus',
      options: { async: false, inverse: 'positions' }
    },
    {
      kind: 'belongsTo',
      name: 'instrument',
      type: 'instrument',
      // eslint-disable-next-line unicorn/no-null -- WarpDrive requires an explicit null inverse to mark the relationship unidirectional
      options: { async: false, inverse: null }
    },
  ],
  traits: ['timestamps']
});

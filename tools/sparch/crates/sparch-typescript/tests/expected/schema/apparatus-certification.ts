import { withDefaults } from '@warp-drive/legacy/model/migration-support';

export const apparatusCertificationSchema = withDefaults({
  type: 'apparatus-certification',
  fields: [
    { kind: 'attribute', name: 'level' },
    {
      kind: 'belongsTo',
      name: 'apparatus',
      type: 'apparatus',
      options: { async: false, inverse: 'certification' }
    },
  ],
  traits: ['timestamps']
});

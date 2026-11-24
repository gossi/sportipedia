import { withDefaults } from '@warp-drive/legacy/model/migration-support';

export const instrumentSchema = withDefaults({
  type: 'instrument',
  fields: [
    { kind: 'attribute', name: 'title' },
    { kind: 'attribute', name: 'description' },
  ],
  traits: ['timestamps']
});

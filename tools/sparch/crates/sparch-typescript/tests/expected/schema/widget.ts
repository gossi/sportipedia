import { withDefaults } from '@warp-drive/legacy/model/migration-support';

export const widgetSchema = withDefaults({
  type: 'widget',
  fields: [
    { kind: 'attribute', name: 'title' },
    { kind: 'attribute', name: 'archivedAt' },
    { kind: 'attribute', name: 'coachId' },
    { kind: 'attribute', name: 'description' },
    { kind: 'attribute', name: 'label' },
    { kind: 'attribute', name: 'teamId' },
  ],
  traits: ['timestamps']
});

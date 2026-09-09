import {
  EQUIPMENTS,
  getEquipmentDefaultArgs,
  makeEquipmenDecorator,
  makeEquipmentArgTypes
} from '#equipment-test-support';
import preview from '#storybook/preview.ts';

import { ArchiveDialog, type ArchiveDialogSignature } from './archive-dialog.gts';

const meta = preview.type<{ args: ArchiveDialogSignature }>().meta({
  title: 'Equipment/UI/ArchiveDialog',
  component: ArchiveDialog,
  tags: ['!autodocs'],
  render: (args) => <template>
    <ArchiveDialog @equipment={{args.equipment}} @confirm={{args.confirm}} open />
  </template>,
  argTypes: {
    ...makeEquipmentArgTypes(EQUIPMENTS),
    confirm: {
      table: {
        category: 'Actions'
      }
    }
  },
  // @ts-expect-error csf-next has some troubles with the types
  args: {
    ...getEquipmentDefaultArgs()
  },
  decorators: makeEquipmenDecorator(EQUIPMENTS)
});

export const Default = meta.story();

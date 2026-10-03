import {
  EQUIPMENTS,
  getEquipmentDefaultArgs,
  makeEquipmenDecorator,
  makeEquipmentArgTypes
} from '#equipment-test-support';

import { ArchiveDialog, type ArchiveDialogSignature } from './archive-dialog.gts';

import type { Meta, StoryObj } from 'ember-storybook';

export default {
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
  // @ts-expect-error the decorator swaps the slug preset for the resolved Equipment
  args: {
    ...getEquipmentDefaultArgs()
  },
  decorators: makeEquipmenDecorator(EQUIPMENTS)
} satisfies Meta<ArchiveDialogSignature['Args']>;

export const Default: StoryObj<ArchiveDialogSignature['Args']> = {};

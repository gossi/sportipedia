import {
  EQUIPMENTS,
  getEquipmentDefaultArgs,
  makeEquipmenDecorator,
  makeEquipmentArgTypes
} from '#equipment-test-support';

import { ArchiveDialog } from './archive-dialog.gts';

import type { Meta, StoryObj } from 'ember-storybook';

export default {
  title: 'Equipment/UI/ArchiveDialog',
  component: ArchiveDialog,
  tags: ['vitest', '!autodocs'],
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
  args: {
    ...getEquipmentDefaultArgs()
  },
  decorators: makeEquipmenDecorator(EQUIPMENTS)
} satisfies Meta;

export const Default: StoryObj = {};

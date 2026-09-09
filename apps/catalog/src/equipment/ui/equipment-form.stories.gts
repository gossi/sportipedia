import {
  EQUIPMENTS,
  getEquipmentDefaultArgs,
  makeEquipmenDecorator,
  makeEquipmentArgTypes,
  UNICYCLE
} from '#equipment-test-support';
import preview from '#storybook/preview.ts';

import { EquipmentForm } from './equipment-form.gts';

const meta = preview.meta({
  title: 'Equipment/UI/EquipmentForm',
  component: EquipmentForm,
  tags: ['!autodocs'],
  argTypes: {
    // ...makeEquipmentArgTypes(EQUIPMENTS),
    confirm: {
      table: {
        category: 'Actions'
      }
    }
  },
  args: {
    equipment: UNICYCLE
    // ...getEquipmentDefaultArgs()
  },
  decorators: makeEquipmenDecorator(EQUIPMENTS)
});

export const Default = meta.story();

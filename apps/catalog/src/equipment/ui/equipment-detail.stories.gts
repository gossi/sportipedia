import { action } from 'storybook/actions';

import {
  APPARATUSES,
  BALANCE_BEAM,
  EQUIPMENTS,
  getEquipmentDefaultArgs,
  INSTRUMENTS,
  makeEquipmenDecorator,
  makeEquipmentArgTypes,
  UNICYCLE
} from '#equipment-test-support';
import { CUSTOM, withCustom } from '#tests/support/storybook.ts';

import { EquipmentDetail } from './equipment-detail.gts';

import type { StoryObj } from 'ember-storybook';

export default {
  title: 'Equipment/UI/Detail',
  component: EquipmentDetail,
  tags: ['vitest', '!autodocs'],
  parameters: {
    controls: {
      sort: 'none'
    }
  },
  argTypes: {
    ...makeEquipmentArgTypes(EQUIPMENTS),
    archive: {
      table: {
        category: 'Actions'
      }
    },
    editHref: {
      table: {
        category: 'Actions'
      }
    },
    archivingAllowed: {
      table: {
        category: 'Abilities'
      }
    },
    editingAllowed: {
      table: {
        category: 'Abilities'
      }
    }
  },
  args: {
    archive: action('archive'),
    ...getEquipmentDefaultArgs(UNICYCLE)
  },
  decorators: makeEquipmenDecorator(EQUIPMENTS)
};

export const Equipment: StoryObj = {};

export const Instrument: StoryObj = {
  argTypes: {
    equipment: {
      options: withCustom(INSTRUMENTS.map((i) => i.slug))
    }
  },
  args: {
    equipment: UNICYCLE.slug
  }
};

export const Apparatus: StoryObj = {
  argTypes: {
    equipment: {
      options: withCustom(APPARATUSES.map((i) => i.slug))
    }
  },
  args: {
    equipment: BALANCE_BEAM.slug
  }
};

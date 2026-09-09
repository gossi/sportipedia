import { action } from 'storybook/actions';

import {
  APPARATUSES,
  BALANCE_BEAM,
  EQUIPMENTS,
  getEquipmentDefaultArgs,
  INSTRUMENTS,
  makeEquipmenDecorator,
  makeEquipmentArgTypes,
  makeEquipmentMeta,
  UNICYCLE
} from '#equipment-test-support';
import preview from '#storybook/preview';
import { withCustom } from '#tests/support/storybook.ts';

import { EquipmentDetail } from './equipment-detail.gts';

// this is a cool way to wrap your meta across multiple components that share
// the same domain model
const withEquipment = makeEquipmentMeta(EQUIPMENTS, UNICYCLE);

const data = withEquipment({
  title: 'Equipment/UI/Detail',
  component: EquipmentDetail,
  tags: ['vitest', '!autodocs'],
  parameters: {
    controls: {
      sort: 'none'
    }
  },
  argTypes: {
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
    archive: action('archive')
  }
});

// here with all the runtime "extensions"
const meta = preview.meta({
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
});

export const Equipment = meta.story({});

export const Instrument = meta.story({
  argTypes: {
    equipment: {
      options: withCustom(INSTRUMENTS.map((i) => i.slug))
    }
  },
  args: {
    equipment: UNICYCLE.slug
  }
});

export const Apparatus = meta.story({
  argTypes: {
    equipment: {
      options: withCustom(APPARATUSES.map((i) => i.slug))
    }
  },
  args: {
    equipment: BALANCE_BEAM.slug
  }
});

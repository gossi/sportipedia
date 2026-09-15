import { Type } from '@warp-drive/core/types/symbols';

import { CUSTOM } from '#tests/support/storybook.ts';

import { findEquipmentBySlug } from './fixtures/equipments';
import { UNICYCLE } from './fixtures/instruments';

import type { Equipment } from '#/equipment/domain-objects/equipment';
import type { Meta } from 'ember-storybook';
import type { Conditional, DecoratorFunction, InputType } from 'storybook/internal/csf';

export function makeDomainObjectArgTypes(options?: {
  category?: string;
  subcategory?: string;
  condition?: Conditional;
}): Record<string, InputType> {
  const table = {
    category: 'Domain Object',
    subcategory: 'Equipment',
    ...options
  };
  const condition = options?.condition ?? {
    arg: 'equipment',
    eq: CUSTOM
  };

  return {
    slug: {
      type: {
        required: true,
        name: 'string'
      },
      if: condition,
      table
    },
    title: {
      type: {
        required: true,
        name: 'string'
      },
      if: condition,
      table
    },
    description: {
      type: {
        required: true,
        name: 'string'
      },
      if: condition,
      table
    }
  };
}

export function makePresetControl(collection: Equipment[]): InputType {
  return {
    control: {
      type: 'select',
      labels: {
        ...Object.fromEntries(collection.map((e) => [e.slug, e.title]))
      }
    },
    options: [CUSTOM, ...collection.map((i) => i.slug)]
  };
}

export function makeEquipmentArgTypes(
  collection: Equipment[],
  options?: {
    category?: string;
    subcategory?: string;
    condition?: Conditional;
  }
): Record<string, InputType> {
  return {
    equipment: {
      ...makePresetControl(collection),
      table: {
        category: options?.category ?? 'Domain Object'
      }
    },
    ...makeDomainObjectArgTypes(options)
  };
}

export interface EquipmentArgs {
  // preset: boolean;
  equipment: string;
  title: string;
  slug: string;
  description: string;
}

export function getEquipmentFromArgs(args: EquipmentArgs, collection: Equipment[]): Equipment {
  return args.equipment === CUSTOM
    ? {
        [Type]: 'instrument',
        title: args.title,
        slug: args.slug,
        description: args.description,
        id: args.slug,
        createdAt: Temporal.Now.plainDateTimeISO(),
        updatedAt: Temporal.Now.plainDateTimeISO()
      }
    : (findEquipmentBySlug(args.equipment, collection) as Equipment);
}

export function makeEquipmenDecorator(collection: Equipment[]): DecoratorFunction {
  return (story, { args }) => {
    const equipment = getEquipmentFromArgs(args as EquipmentArgs, collection);

    // eslint-disable-next-line @typescript-eslint/no-unsafe-return
    return story({ args: { ...args, equipment } });
  };
}

export function getEquipmentDefaultArgs(equipment: Equipment = UNICYCLE) {
  return {
    equipment: equipment.slug,
    title: equipment.title,
    slug: equipment.slug,
    description: equipment.description
  };
}

export function makeEquipmentMeta(
  collection: Equipment[],
  equipment: Equipment,
  options?: {
    category?: string;
    subcategory?: string;
  }
) {
  return (meta: Meta): Meta => {
    const argTypes = {
      equipment: {
        ...makePresetControl(collection),
        table: {
          category: options?.category ?? 'Domain Object'
        }
      },
      ...makeDomainObjectArgTypes(options),
      ...meta.argTypes
    };
    const decorators = meta.decorators
      ? Array.isArray(meta.decorators)
        ? meta.decorators
        : [meta.decorators]
      : [];

    return {
      ...meta,
      argTypes,
      args: {
        ...meta.args,
        ...getEquipmentDefaultArgs(equipment)
      },
      decorators: [...decorators, makeEquipmenDecorator(collection)]
    };
  };
}

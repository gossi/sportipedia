import { Type } from '@warp-drive/core/types/symbols';

import { APPARATUSES, INSTRUMENTS } from '#equipment-test-support';
import { CUSTOM } from '#tests/support/storybook.ts';

import { findPositionBySlug, UNICYCLE_RIDING } from './fixtures/positions';

import type { Position } from '#athlete';
import type { Meta } from 'ember-storybook';
import type { Conditional, DecoratorFunction, InputType } from 'storybook/internal/csf';

export function makeDomainObjectArgTypes(options?: {
  category?: string;
  subcategory?: string;
  condition?: Conditional;
}): Record<string, InputType> {
  const table = {
    category: 'Domain Object',
    subcategory: 'Position',
    ...options
  };
  const condition = options?.condition ?? {
    arg: 'position',
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
    rawSlug: {
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
    },
    instrument: {
      control: {
        type: 'select',
        labels: {
          ...Object.fromEntries(INSTRUMENTS.map((e) => [e.slug, e.title]))
        }
      },
      options: INSTRUMENTS,
      if: condition,
      table
    },
    apparatus: {
      control: {
        type: 'select',
        labels: {
          ...Object.fromEntries(APPARATUSES.map((e) => [e.slug, e.title]))
        }
      },
      options: APPARATUSES,
      if: condition,
      table
    }
  };
}

export function makePresetControl(collection: Position[]): InputType {
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

export function makePositionArgTypes(
  collection: Position[],
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

export interface PositionArgs {
  // preset: boolean;
  equipment: string;
  title: string;
  slug: string;
  rawSlug: string;
  description: string;
  instrument?: string;
  apparatus?: string;
}

export function getPositionFromArgs(args: PositionArgs, collection: Position[]): Position {
  return args.equipment === CUSTOM
    ? {
        [Type]: 'position',
        title: args.title,
        slug: args.slug,
        rawSlug: args.rawSlug,
        description: args.description,
        id: args.slug,
        createdAt: Temporal.Now.plainDateTimeISO(),
        updatedAt: Temporal.Now.plainDateTimeISO()
      }
    : (findPositionBySlug(args.equipment, collection) as Position);
}

export function makePositionDecorator(collection: Position[]): DecoratorFunction {
  return (story, { args }) => {
    const equipment = getPositionFromArgs(args as PositionArgs, collection);

    // eslint-disable-next-line @typescript-eslint/no-unsafe-return
    return story({ args: { ...args, equipment } });
  };
}

export function getPositionDefaultArgs(position: Position = UNICYCLE_RIDING) {
  return {
    equipment: position.slug,
    title: position.title,
    slug: position.slug,
    rawSlug: position.rawSlug,
    description: position.description
  };
}

export function makePositionMeta(
  collection: Position[],
  position: Position,
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
        ...getPositionDefaultArgs(position)
      },
      decorators: [...decorators, makePositionDecorator(collection)]
    };
  };
}

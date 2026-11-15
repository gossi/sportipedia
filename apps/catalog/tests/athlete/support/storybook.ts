import { Type } from '@warp-drive/core/types/symbols';

import {
  APPARATUSES,
  findApparatusBySlug,
  findInstrumentBySlug,
  INSTRUMENTS
} from '#equipment-test-support';
import { CUSTOM } from '#tests/support/storybook.ts';

import { findPositionBySlug, UNICYCLE_RIDING } from './fixtures/positions';

import type { Position } from '#athlete';
import type { Meta } from 'ember-storybook';
import type { Conditional, DecoratorFunction, InputType } from 'storybook/internal/csf';

export function makePositionPresetControl(collection: Position[]): InputType {
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

export function makePositionArgTypes(options?: {
  category?: string;
  subcategory?: string;
  condition?: Conditional;
}): Record<string, InputType> {
  const table = {
    category: 'Domain Object',
    subcategory: 'Position',
    ...options
  };
  const condition = options?.condition ?? { arg: 'position', eq: CUSTOM };

  return {
    title: {
      type: { required: true, name: 'string' },
      if: condition,
      table
    },
    rawSlug: {
      type: { required: true, name: 'string' },
      if: condition,
      table
    },
    slug: {
      type: { required: true, name: 'string' },
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
    },
    description: {
      type: { required: false, name: 'string' },
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
    }
  };
}

export function makePositionArgTypesWithPreset(
  collection: Position[],
  options?: {
    category?: string;
    subcategory?: string;
    condition?: Conditional;
  }
): Record<string, InputType> {
  return {
    position: {
      ...makePositionPresetControl(collection),
      table: { category: options?.category ?? 'Domain Object' }
    },
    ...makePositionArgTypes(options)
  };
}

export interface PositionArgs {
  position: string;
  title: string;
  rawSlug: string;
  slug: string;
  apparatus?: string;
  description?: string;
  instrument?: string;
}

export function getPositionFromArgs(args: PositionArgs, collection: Position[]): Position {
  return args.position === CUSTOM
    ? {
        [Type]: 'position',
        id: args.slug,
        title: args.title,
        rawSlug: args.rawSlug,
        slug: args.slug,
        apparatus: args.apparatus ? findApparatusBySlug(args.apparatus) : undefined,
        description: args.description,
        instrument: args.instrument ? findInstrumentBySlug(args.instrument) : undefined,
        createdAt: Temporal.Now.plainDateTimeISO(),
        updatedAt: Temporal.Now.plainDateTimeISO()
      }
    : (findPositionBySlug(args.position, collection) as Position);
}

export function getPositionDefaultArgs(position: Position = UNICYCLE_RIDING) {
  return {
    position: position.slug,
    title: position.title,
    rawSlug: position.rawSlug,
    slug: position.slug,
    apparatus: position.apparatus?.slug,
    description: position.description,
    instrument: position.instrument?.slug
  };
}

export function makePositionDecorator(collection: Position[]): DecoratorFunction {
  return (story, { args }) => {
    const position = getPositionFromArgs(args as PositionArgs, collection);

    // eslint-disable-next-line @typescript-eslint/no-unsafe-return
    return story({ args: { ...args, position } });
  };
}

export function makePositionMeta(
  collection: Position[],
  position: Position,
  options?: { category?: string; subcategory?: string }
): (meta: Meta) => Meta {
  return (meta: Meta): Meta => {
    const argTypes = {
      ...makePositionArgTypesWithPreset(collection, options),
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
      args: { ...meta.args, ...getPositionDefaultArgs(position) },
      decorators: [...decorators, makePositionDecorator(collection)]
    };
  };
}

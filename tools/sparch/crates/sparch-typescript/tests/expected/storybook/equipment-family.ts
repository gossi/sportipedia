import { Type } from '@warp-drive/core/types/symbols';

import { CUSTOM } from '#tests/support/storybook.ts';

import { findInstrumentBySlug, UNICYCLE } from './fixtures/instruments';
import { APPARATUS_CERTIFICATIONS } from '#equipment-test-support';
import { POSITIONS } from '#athlete-test-support';
import { TAGS } from '#equipment-test-support';
import { findApparatusBySlug } from './fixtures/apparatuses';
import { findApparatusCertificationBySlug } from '#equipment-test-support';
import { findPositionBySlug } from '#athlete-test-support';
import { findTagBySlug } from '#equipment-test-support';
import { PARALLEL_BARS } from './fixtures/apparatuses';

import type { Instrument } from '#equipment';
import type { Meta } from 'ember-storybook';
import type { Conditional, DecoratorFunction, InputType } from 'storybook/internal/csf';


export function makeInstrumentPresetControl(collection: Instrument[]): InputType {
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


export function makeInstrumentArgTypes(options?: {
  category?: string;
  subcategory?: string;
  condition?: Conditional
}): Record<string, InputType> {
  const table = {
    category: 'Domain Object',
    subcategory: 'Instrument',
    ...options
  };
  const condition = options?.condition ?? { arg: 'instrument', eq: CUSTOM };

  return {
    title: {
      type: { required: true, name: 'string' },
      if: condition,
      table
    },
    slug: {
      type: { required: true, name: 'string' },
      if: condition,
      table
    },
    description: {
      type: { required: false, name: 'string' },
      if: condition,
      table
    },
  };
}


export function makeInstrumentArgTypesWithPreset(
  collection: Instrument[],
  options?: {
    category?: string;
    subcategory?: string;
    condition?: Conditional
  }
): Record<string, InputType> {
  return {
    instrument: {
      ...makeInstrumentPresetControl(collection),
      table: { category: options?.category ?? 'Domain Object' }
    },
    ...makeInstrumentArgTypes(options)
  };
}


export interface InstrumentArgs {
  instrument: string;
  title: string;
  slug: string;
  description?: string;
}


export function getInstrumentFromArgs(args: InstrumentArgs, collection: Instrument[]): Instrument {
  return args.instrument === CUSTOM
    ? {
      [Type]: 'instrument',
      id: args.slug,
      title: args.title,
      slug: args.slug,
      description: args.description,
      createdAt: Temporal.Now.plainDateTimeISO(),
      updatedAt: Temporal.Now.plainDateTimeISO()
    }
    : (findInstrumentBySlug(args.instrument, collection) as Instrument);
}


export function getInstrumentDefaultArgs(instrument: Instrument = UNICYCLE) {
  return {
    instrument: instrument.slug,
    title: instrument.title,
    slug: instrument.slug,
    description: instrument.description,
  };
}


export function makeInstrumentDecorator(collection: Instrument[]): DecoratorFunction {
  return (story, { args }) => {
    const instrument = getInstrumentFromArgs(args as InstrumentArgs, collection);

    // eslint-disable-next-line @typescript-eslint/no-unsafe-return
    return story({ args: { ...args, instrument } });
  };
}


export function makeInstrumentMeta(
  collection: Instrument[],
  instrument: Instrument,
  options?: { category?: string; subcategory?: string }
): (meta: Meta) => Meta {
  return (meta: Meta): Meta => {
    const argTypes = {
      ...makeInstrumentArgTypesWithPreset(collection, options),
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
      args: { ...meta.args, ...getInstrumentDefaultArgs(instrument) },
      decorators: [...decorators, makeInstrumentDecorator(collection)]
    };
  };
}


export function makeApparatusPresetControl(collection: Apparatus[]): InputType {
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



export function makeApparatusArgTypes(options?: {
  category?: string;
  subcategory?: string;
  condition?: Conditional
}): Record<string, InputType> {
  const table = {
    category: 'Domain Object',
    subcategory: 'Apparatus',
    ...options
  };
  const condition = options?.condition ?? { arg: 'apparatus', eq: CUSTOM };

  return {
    title: {
      type: { required: true, name: 'string' },
      if: condition,
      table
    },
    slug: {
      type: { required: true, name: 'string' },
      if: condition,
      table
    },
    certification: {
      control: {
        type: 'select',
        labels: {
          ...Object.fromEntries(APPARATUS_CERTIFICATIONS.map((e) => [e.slug, e.title]))
        }
      },
      options: APPARATUS_CERTIFICATIONS,
      if: condition,
      table
    },
    description: {
      type: { required: false, name: 'string' },
      if: condition,
      table
    },
    positions: {
      control: {
        type: 'select',
        labels: {
          ...Object.fromEntries(POSITIONS.map((e) => [e.slug, e.title]))
        }
      },
      options: POSITIONS,
      if: condition,
      table
    },
    tags: {
      control: {
        type: 'select',
        labels: {
          ...Object.fromEntries(TAGS.map((e) => [e.slug, e.title]))
        }
      },
      options: TAGS,
      if: condition,
      table
    },
  };
}



export function makeApparatusArgTypesWithPreset(
  collection: Apparatus[],
  options?: {
    category?: string;
    subcategory?: string;
    condition?: Conditional
  }
): Record<string, InputType> {
  return {
    apparatus: {
      ...makeApparatusPresetControl(collection),
      table: { category: options?.category ?? 'Domain Object' }
    },
    ...makeApparatusArgTypes(options)
  };
}



export interface ApparatusArgs {
  apparatus: string;
  title: string;
  slug: string;
  certification?: string;
  description?: string;
  positions?: string;
  tags?: string;
}



export function getApparatusFromArgs(args: ApparatusArgs, collection: Apparatus[]): Apparatus {
  return args.apparatus === CUSTOM
    ? {
      [Type]: 'apparatus',
      id: args.slug,
      title: args.title,
      slug: args.slug,
      certification: args.certification ? findApparatusCertificationBySlug(args.certification) : undefined,
      description: args.description,
      positions: args.positions ? findPositionBySlug(args.positions) : undefined,
      tags: args.tags ? findTagBySlug(args.tags) : undefined,
      createdAt: Temporal.Now.plainDateTimeISO(),
      updatedAt: Temporal.Now.plainDateTimeISO()
    }
    : (findApparatusBySlug(args.apparatus, collection) as Apparatus);
}



export function getApparatusDefaultArgs(apparatus: Apparatus = PARALLEL_BARS) {
  return {
    apparatus: apparatus.slug,
    title: apparatus.title,
    slug: apparatus.slug,
    certification: apparatus.certification?.slug,
    description: apparatus.description,
    positions: apparatus.positions?.slug,
    tags: apparatus.tags?.slug,
  };
}



export function makeApparatusDecorator(collection: Apparatus[]): DecoratorFunction {
  return (story, { args }) => {
    const apparatus = getApparatusFromArgs(args as ApparatusArgs, collection);

    // eslint-disable-next-line @typescript-eslint/no-unsafe-return
    return story({ args: { ...args, apparatus } });
  };
}



export function makeApparatusMeta(
  collection: Apparatus[],
  apparatus: Apparatus,
  options?: { category?: string; subcategory?: string }
): (meta: Meta) => Meta {
  return (meta: Meta): Meta => {
    const argTypes = {
      ...makeApparatusArgTypesWithPreset(collection, options),
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
      args: { ...meta.args, ...getApparatusDefaultArgs(apparatus) },
      decorators: [...decorators, makeApparatusDecorator(collection)]
    };
  };
}



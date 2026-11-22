import { Type } from '@warp-drive/core/types/symbols';

import { CUSTOM } from '#tests/support/storybook.ts';

import { findWidgetBySlug, CLASSIC_WIDGET } from './fixtures/widgets';

import type { Widget } from '#equipment';
import type { Meta } from 'ember-storybook';
import type { Conditional, DecoratorFunction, InputType } from 'storybook/internal/csf';


export function makeWidgetPresetControl(collection: Widget[]): InputType {
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


export function makeWidgetArgTypes(options?: {
  category?: string;
  subcategory?: string;
  condition?: Conditional
}): Record<string, InputType> {
  const table = {
    category: 'Domain Object',
    subcategory: 'Widget',
    ...options
  };
  const condition = options?.condition ?? { arg: 'widget', eq: CUSTOM };

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
    archivedAt: {
      type: { required: false, name: 'string' },
      if: condition,
      table
    },
    coachId: {
      type: { required: false, name: 'string' },
      if: condition,
      table
    },
    description: {
      type: { required: false, name: 'string' },
      if: condition,
      table
    },
    label: {
      type: { required: false, name: 'string' },
      if: condition,
      table
    },
    teamId: {
      type: { required: false, name: 'string' },
      if: condition,
      table
    },
  };
}


export function makeWidgetArgTypesWithPreset(
  collection: Widget[],
  options?: {
    category?: string;
    subcategory?: string;
    condition?: Conditional
  }
): Record<string, InputType> {
  return {
    widget: {
      ...makeWidgetPresetControl(collection),
      table: { category: options?.category ?? 'Domain Object' }
    },
    ...makeWidgetArgTypes(options)
  };
}


export interface WidgetArgs {
  widget: string;
  title: string;
  slug: string;
  archivedAt?: string;
  coachId?: string;
  description?: string;
  label?: string;
  teamId?: string;
}


export function getWidgetFromArgs(args: WidgetArgs, collection: Widget[]): Widget {
  return args.widget === CUSTOM
    ? {
      [Type]: 'widget',
      id: args.slug,
      title: args.title,
      slug: args.slug,
      archivedAt: args.archivedAt,
      coachId: args.coachId,
      description: args.description,
      label: args.label,
      teamId: args.teamId,
      createdAt: Temporal.Now.plainDateTimeISO(),
      updatedAt: Temporal.Now.plainDateTimeISO()
    }
    : (findWidgetBySlug(args.widget, collection) as Widget);
}


export function getWidgetDefaultArgs(widget: Widget = CLASSIC_WIDGET) {
  return {
    widget: widget.slug,
    title: widget.title,
    slug: widget.slug,
    archivedAt: widget.archivedAt,
    coachId: widget.coachId,
    description: widget.description,
    label: widget.label,
    teamId: widget.teamId,
  };
}


export function makeWidgetDecorator(collection: Widget[]): DecoratorFunction {
  return (story, { args }) => {
    const widget = getWidgetFromArgs(args as WidgetArgs, collection);

    // eslint-disable-next-line @typescript-eslint/no-unsafe-return
    return story({ args: { ...args, widget } });
  };
}


export function makeWidgetMeta(
  collection: Widget[],
  widget: Widget,
  options?: { category?: string; subcategory?: string }
): (meta: Meta) => Meta {
  return (meta: Meta): Meta => {
    const argTypes = {
      ...makeWidgetArgTypesWithPreset(collection, options),
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
      args: { ...meta.args, ...getWidgetDefaultArgs(widget) },
      decorators: [...decorators, makeWidgetDecorator(collection)]
    };
  };
}


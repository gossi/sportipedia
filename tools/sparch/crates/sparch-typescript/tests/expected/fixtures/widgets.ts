import { Type } from '@warp-drive/core/types/symbols';

import type { Widget } from '#equipment';
import type { ID, Slug } from '#/support/domain-objects/fields';

export const CLASSIC_WIDGET: Widget = Object.freeze({
  [Type]: 'widget',
  id: 'equipment:widget:classic-widget',
  title: 'Classic Widget',
  slug: 'classic-widget',
  coachId: 'equipment:coach:head-coach',
  description: 'The original widget of the fixture world',
  label: 'classic',
  teamId: 'equipment:team:first-team',
  createdAt: Temporal.Now.plainDateTimeISO(),
  updatedAt: Temporal.Now.plainDateTimeISO()
});

export const GADGET_2000: Widget = Object.freeze({
  [Type]: 'widget',
  id: 'equipment:widget:gadget-2000',
  title: 'Gadget 2000',
  slug: 'gadget-2000',
  description: 'A newer widget, unlabeled and unassigned',
  createdAt: Temporal.Now.plainDateTimeISO(),
  updatedAt: Temporal.Now.plainDateTimeISO()
});


export const WIDGETS = [
  CLASSIC_WIDGET,
  GADGET_2000
];

export function findWidgetById(
  id: ID,
  widgets: Widget[] = WIDGETS
): Widget | undefined {
  return widgets.find((i) => i.id === id);
}

export function findWidgetBySlug(
  slug: Slug,
  widgets: Widget[] = WIDGETS
): Widget | undefined {
  return widgets.find((i) => i.slug === slug);
}

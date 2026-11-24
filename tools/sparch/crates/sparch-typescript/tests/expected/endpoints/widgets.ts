import { HttpResponse, type RequestHandler, type ResponseResolver } from 'msw';

import { toJsonApiDocument } from '#test-support/data/jsonapi.ts';
import { toResource } from '#test-support/data/resources.ts';
import { type Endpoint, makeJsonResponder, mock } from '#test-support/msw';

import { WIDGETS } from '../fixtures/widgets';

import type { Widget } from '#equipment';

// Utils

export function makeWidgetResponse(widget: Widget): ResponseResolver {
  return makeJsonResponder(toJsonApiDocument(toResource(widget)));
}

// Endpoints

export function makeArchiveWidgetEndpoint(): Endpoint {
  return { method: 'POST', path: `**/catalog/equipment/widgets/archive-widget` };
}


export function makeCreateWidgetEndpoint(): Endpoint {
  return { method: 'POST', path: `**/catalog/equipment/widgets/create-widget` };
}


export function makeEditWidgetEndpoint(): Endpoint {
  return { method: 'POST', path: `**/catalog/equipment/widgets/edit-widget` };
}


export function makeNoteWidgetEndpoint(): Endpoint {
  return { method: 'POST', path: `**/catalog/equipment/widgets/note-widget` };
}


export function makeRelabelWidgetEndpoint(): Endpoint {
  return { method: 'POST', path: `**/catalog/equipment/widgets/relabel-widget` };
}


export function makeListWidgetsEndpoint(): Endpoint {
  return { method: 'GET', path: `**/catalog/equipment/widgets` };
}


export function makeReadWidgetEndpoint(idOrSlug: string): Endpoint {
  return { method: 'GET', path: `**/catalog/equipment/widgets/${idOrSlug}` };
}

// Mocks

export function mockArchiveWidget(): RequestHandler {
  return mock(makeArchiveWidgetEndpoint(), async ({ request }) => {
    const widget = (await request.json()) as Widget;

    return HttpResponse.json(toJsonApiDocument(toResource(widget)));
  });
}


export function mockCreateWidget(): RequestHandler {
  return mock(makeCreateWidgetEndpoint(), async ({ request }) => {
    const widget = (await request.json()) as Widget;

    return HttpResponse.json(toJsonApiDocument(toResource(widget)));
  });
}


export function mockEditWidget(): RequestHandler {
  return mock(makeEditWidgetEndpoint(), async ({ request }) => {
    const widget = (await request.json()) as Widget;

    return HttpResponse.json(toJsonApiDocument(toResource(widget)));
  });
}


export function mockNoteWidget(): RequestHandler {
  return mock(makeNoteWidgetEndpoint(), async ({ request }) => {
    const widget = (await request.json()) as Widget;

    return HttpResponse.json(toJsonApiDocument(toResource(widget)));
  });
}


export function mockRelabelWidget(): RequestHandler {
  return mock(makeRelabelWidgetEndpoint(), async ({ request }) => {
    const widget = (await request.json()) as Widget;

    return HttpResponse.json(toJsonApiDocument(toResource(widget)));
  });
}


export function mockListWidgets(widgets: Widget[] = WIDGETS): RequestHandler {
  const data = widgets.map((widget) => toResource(widget));

  return mock(makeListWidgetsEndpoint(), makeJsonResponder(toJsonApiDocument(data)));
}


export function mockReadWidget(widget: Widget): RequestHandler {
  return mock(makeReadWidgetEndpoint(widget.slug), makeWidgetResponse(widget));
}

import { HttpResponse, type RequestHandler, type ResponseResolver } from 'msw';

import { toJsonApiDocument } from '#test-support/data/jsonapi.ts';
import { toResource } from '#test-support/data/resources.ts';
import { type Endpoint, makeJsonResponder, mock } from '#test-support/msw';

import { POSITIONS } from '../fixtures/positions';

import type { Position } from '#athlete';

// Utils

export function makePositionResponse(position: Position): ResponseResolver {
  return makeJsonResponder(toJsonApiDocument(toResource(position)));
}

// Endpoints

export function makeCatalogPositionEndpoint(): Endpoint {
  return { method: 'POST', path: `**/catalog/athlete/positions/catalog-position` };
}

export function makeReadPositionEndpoint(slug: string): Endpoint {
  return { method: 'GET', path: `**/catalog/athlete/positions/${slug}` };
}

export function makeListPositionesEndpoint(): Endpoint {
  return { method: 'GET', path: '**/catalog/athlete/positions' };
}

// Mocks

export function mockCatalogPosition(): RequestHandler {
  return mock(makeCatalogPositionEndpoint(), async ({ request }) => {
    const position = (await request.json()) as Position;

    return HttpResponse.json(toJsonApiDocument(toResource(position)));
  });
}

export function mockReadPosition(position: Position): RequestHandler {
  return mock(makeReadPositionEndpoint(position.slug), makePositionResponse(position));
}

export function mockListPositiones(positiones: Position[] = POSITIONS): RequestHandler {
  const data = positiones.map((position) => toResource(position));

  return mock(makeListPositionesEndpoint(), makeJsonResponder(toJsonApiDocument(data)));
}

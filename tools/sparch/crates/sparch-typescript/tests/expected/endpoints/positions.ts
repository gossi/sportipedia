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

export function makeArchivePositionEndpoint(): Endpoint {
  return { method: 'POST', path: `**/catalog/athlete/positions/archive-position` };
}


export function makeCatalogPositionEndpoint(): Endpoint {
  return { method: 'POST', path: `**/catalog/athlete/positions/catalog-position` };
}


export function makeEditPositionEndpoint(): Endpoint {
  return { method: 'POST', path: `**/catalog/athlete/positions/edit-position` };
}


export function makeListPositionsEndpoint(): Endpoint {
  return { method: 'GET', path: `**/catalog/athlete/positions` };
}


export function makeReadPositionEndpoint(idOrSlug: string): Endpoint {
  return { method: 'GET', path: `**/catalog/athlete/positions/${idOrSlug}` };
}

// Mocks

export function mockArchivePosition(): RequestHandler {
  return mock(makeArchivePositionEndpoint(), async ({ request }) => {
    const position = (await request.json()) as Position;

    return HttpResponse.json(toJsonApiDocument(toResource(position)));
  });
}


export function mockCatalogPosition(): RequestHandler {
  return mock(makeCatalogPositionEndpoint(), async ({ request }) => {
    const position = (await request.json()) as Position;

    return HttpResponse.json(toJsonApiDocument(toResource(position)));
  });
}


export function mockEditPosition(): RequestHandler {
  return mock(makeEditPositionEndpoint(), async ({ request }) => {
    const position = (await request.json()) as Position;

    return HttpResponse.json(toJsonApiDocument(toResource(position)));
  });
}


export function mockListPositions(positions: Position[] = POSITIONS): RequestHandler {
  const data = positions.map((position) => toResource(position));

  return mock(makeListPositionsEndpoint(), makeJsonResponder(toJsonApiDocument(data)));
}


export function mockReadPosition(position: Position): RequestHandler {
  return mock(makeReadPositionEndpoint(position.slug), makePositionResponse(position));
}

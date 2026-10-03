import { HttpResponse, type RequestHandler, type ResponseResolver } from 'msw';

import { toJsonApiDocument } from '#test-support/data/jsonapi.ts';
import { toResource } from '#test-support/data/resources.ts';
import { type Endpoint, makeJsonResponder, mock } from '#test-support/msw';

import { APPARATUSES } from '../fixtures/apparatuses';

import type { Apparatus } from '#equipment';

// Utils

export function makeApparatusResponse(apparatus: Apparatus): ResponseResolver {
  return makeJsonResponder(toJsonApiDocument(toResource(apparatus)));
}

// Endpoints

export function makeCatalogApparatusEndpoint(): Endpoint {
  return { method: 'POST', path: `**/catalog/equipment/apparatuses/catalog-apparatus` };
}

export function makeReadApparatusEndpoint(slug: string): Endpoint {
  return { method: 'GET', path: `**/catalog/equipment/apparatuses/${slug}` };
}

export function makeListApparatusesEndpoint(): Endpoint {
  return { method: 'GET', path: '**/catalog/equipment/apparatuses' };
}

// Mocks

export function mockCatalogApparatus(): RequestHandler {
  return mock(makeCatalogApparatusEndpoint(), async ({ request }) => {
    const apparatus = (await request.json()) as Apparatus;

    return HttpResponse.json(toJsonApiDocument(toResource(apparatus)));
  });
}

export function mockReadApparatus(apparatus: Apparatus): RequestHandler {
  return mock(makeReadApparatusEndpoint(apparatus.slug), makeApparatusResponse(apparatus));
}

export function mockListApparatuses(apparatuses: Apparatus[] = APPARATUSES): RequestHandler {
  const data = apparatuses.map((apparatus) => toResource(apparatus));

  return mock(makeListApparatusesEndpoint(), makeJsonResponder(toJsonApiDocument(data)));
}

import { toJsonApiDocument } from '#test-support/data/jsonapi.ts';
import { toResource } from '#test-support/data/resources.ts';
import { type Endpoint, makeJsonResponse, mock } from '#test-support/msw';

import { APPARATUSES } from '../fixtures/apparatuses';

import type { Apparatus } from '#equipment';
import type { RequestHandler, ResponseResolver } from 'msw';

export function makeApparatusEndpoint(slug: string): Endpoint {
  return { method: 'GET', path: `**/catalog/equipment/apparatuses/${slug}` };
}

export function makeApparatusesEndpoint(): Endpoint {
  return { method: 'GET', path: '**/catalog/equipment/apparatuses' };
}

export function makeApparatusResponse(apparatus: Apparatus): ResponseResolver {
  return makeJsonResponse(toJsonApiDocument(toResource(apparatus)));
}

export function mockReadApparatus(apparatus: Apparatus): RequestHandler {
  return mock(makeApparatusEndpoint(apparatus.slug), makeApparatusResponse(apparatus));
}

export function mockListApparatuses(apparatuses: Apparatus[] = APPARATUSES): RequestHandler {
  const data = apparatuses.map((apparatus) => toResource(apparatus));

  return mock(makeApparatusesEndpoint(), makeJsonResponse(toJsonApiDocument(data)));
}

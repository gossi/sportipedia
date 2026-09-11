import { toJsonApiDocument } from '#test-support/data/jsonapi.ts';
import { toResource } from '#test-support/data/resources.ts';
import { type Endpoint, makeJsonResponse, mock } from '#test-support/msw';

import { INSTRUMENTS } from '../fixtures/instruments';

import type { Instrument } from '#equipment';
import type { RequestHandler, ResponseResolver } from 'msw';

export function makeInstrumentEndpoint(slug: string): Endpoint {
  return { method: 'GET', path: `**/catalog/equipment/instruments/${slug}` };
}

export function makeInstrumentsEndpoint(): Endpoint {
  return { method: 'GET', path: '**/catalog/equipment/instruments' };
}

export function makeInstrumentResponse(instrument: Instrument): ResponseResolver {
  return makeJsonResponse(toJsonApiDocument(toResource(instrument)));
}

/** Mocks `GET instruments/{slug}` to serve the given instrument. */
export function mockReadInstrument(instrument: Instrument): RequestHandler {
  return mock(makeInstrumentEndpoint(instrument.slug), makeInstrumentResponse(instrument));
}

export function mockListInstruments(instruments: Instrument[] = INSTRUMENTS): RequestHandler {
  const data = instruments.map((instrument) => toResource(instrument));

  return mock(makeInstrumentsEndpoint(), makeJsonResponse(toJsonApiDocument(data)));
}

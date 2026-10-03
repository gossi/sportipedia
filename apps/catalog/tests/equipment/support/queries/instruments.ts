import { HttpResponse, type RequestHandler, type ResponseResolver } from 'msw';

import { toJsonApiDocument } from '#test-support/data/jsonapi.ts';
import { toResource } from '#test-support/data/resources.ts';
import { type Endpoint, makeJsonResponder, mock } from '#test-support/msw';

import { INSTRUMENTS } from '../fixtures/instruments';

import type { Instrument } from '#equipment';

// Utils

export function makeInstrumentResponse(instrument: Instrument): ResponseResolver {
  return makeJsonResponder(toJsonApiDocument(toResource(instrument)));
}

// Endpoints

export function makeCatalogInstrumentEndpoint(): Endpoint {
  return { method: 'POST', path: `**/catalog/equipment/instruments/catalog-instrument` };
}

export function makeReadInstrumentEndpoint(slug: string): Endpoint {
  return { method: 'GET', path: `**/catalog/equipment/instruments/${slug}` };
}

export function makeListInstrumentsEndpoint(): Endpoint {
  return { method: 'GET', path: '**/catalog/equipment/instruments' };
}

// Mocks

export function mockCatalogInstrument(): RequestHandler {
  return mock(makeCatalogInstrumentEndpoint(), async ({ request }) => {
    const apparatus = (await request.json()) as Instrument;

    return HttpResponse.json(toJsonApiDocument(toResource(apparatus)));
  });
}

/** Mocks `GET instruments/{slug}` to serve the given instrument. */
export function mockReadInstrument(instrument: Instrument): RequestHandler {
  return mock(makeReadInstrumentEndpoint(instrument.slug), makeInstrumentResponse(instrument));
}

export function mockListInstruments(instruments: Instrument[] = INSTRUMENTS): RequestHandler {
  const data = instruments.map((instrument) => toResource(instrument));

  return mock(makeListInstrumentsEndpoint(), makeJsonResponder(toJsonApiDocument(data)));
}

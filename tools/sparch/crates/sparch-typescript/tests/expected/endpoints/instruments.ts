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

export function makeArchiveInstrumentEndpoint(): Endpoint {
  return { method: 'POST', path: `**/catalog/equipment/instruments/archive-instrument` };
}


export function makeCatalogInstrumentEndpoint(): Endpoint {
  return { method: 'POST', path: `**/catalog/equipment/instruments/catalog-instrument` };
}


export function makeEditInstrumentEndpoint(): Endpoint {
  return { method: 'POST', path: `**/catalog/equipment/instruments/edit-instrument` };
}


export function makeListInstrumentsEndpoint(): Endpoint {
  return { method: 'GET', path: `**/catalog/equipment/instruments` };
}


export function makeReadInstrumentEndpoint(idOrSlug: string): Endpoint {
  return { method: 'GET', path: `**/catalog/equipment/instruments/${idOrSlug}` };
}

// Mocks

export function mockArchiveInstrument(): RequestHandler {
  return mock(makeArchiveInstrumentEndpoint(), async ({ request }) => {
    const instrument = (await request.json()) as Instrument;

    return HttpResponse.json(toJsonApiDocument(toResource(instrument)));
  });
}


export function mockCatalogInstrument(): RequestHandler {
  return mock(makeCatalogInstrumentEndpoint(), async ({ request }) => {
    const instrument = (await request.json()) as Instrument;

    return HttpResponse.json(toJsonApiDocument(toResource(instrument)));
  });
}


export function mockEditInstrument(): RequestHandler {
  return mock(makeEditInstrumentEndpoint(), async ({ request }) => {
    const instrument = (await request.json()) as Instrument;

    return HttpResponse.json(toJsonApiDocument(toResource(instrument)));
  });
}


export function mockListInstruments(instruments: Instrument[] = INSTRUMENTS): RequestHandler {
  const data = instruments.map((instrument) => toResource(instrument));

  return mock(makeListInstrumentsEndpoint(), makeJsonResponder(toJsonApiDocument(data)));
}


export function mockReadInstrument(instrument: Instrument): RequestHandler {
  return mock(makeReadInstrumentEndpoint(instrument.slug), makeInstrumentResponse(instrument));
}

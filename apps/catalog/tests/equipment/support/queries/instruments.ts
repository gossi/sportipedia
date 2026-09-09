import { http, HttpResponse } from 'msw';

import { toJsonApiDocument, toJsonApiErrorDocument } from '#tests/support/data/jsonapi.ts';
import { toResource } from '#tests/support/data/resources.ts';

import { INSTRUMENTS } from '../fixtures/instruments';

import type { Instrument } from '#equipment';
import type { ApiError } from '#tests/support/data/errors.ts';

export function mockReadInstrument(instrument: Instrument) {
  return http.get<{ id: string }>(`**/catalog/equipment/instruments/${instrument.id}`, () => {
    return HttpResponse.json(toJsonApiDocument(toResource(instrument)));
  });
}

export function mockReadInstrumentWithError(slug: string, error: ApiError) {
  return http.get<{ id: string }>(`**/catalog/equipment/instruments/${slug}`, () => {
    return HttpResponse.json(toJsonApiErrorDocument(error.error), { status: error.status });
  });
}

export function mockListInstruments(instruments: Instrument[] = INSTRUMENTS) {
  return http.get(`**/catalog/equipment/instruments`, () => {
    return HttpResponse.json({ data: instruments.map((i) => toResource(i)) });
  });
}

export function mockListInstrumentsWithError(error: ApiError) {
  return http.get(`**/catalog/equipment/instruments`, () => {
    return HttpResponse.json(toJsonApiErrorDocument(error.error), { status: error.status });
  });
}

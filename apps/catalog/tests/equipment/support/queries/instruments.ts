import { http, HttpResponse } from 'msw';

import { toResource } from '#tests/support/data/resources.ts';

import { SKATEBOARD, UNICYCLE } from '../fixtures/instruments';

import type { Instrument } from '#equipment';

export function readInstrumentMock(instrument: Instrument) {
  return http.get<{ id: string }>(`**/catalog/equipment/instruments/${instrument.id}`, () => {
    return HttpResponse.json(toResource(instrument));
  });
}

export function readInstrumentsMock(instruments: Instrument[] = [UNICYCLE, SKATEBOARD]) {
  return http.get<{ id: string }>(`**/catalog/equipment/instruments`, () => {
    return HttpResponse.json({ data: instruments.map((i) => toResource(i)) });
  });
}

import { http, HttpResponse } from 'msw';

import { toResource } from '#tests/support/data/resources.ts';

import { APPARATUSES } from '../fixtures/apparatuses';

import type { Apparatus } from '#equipment';

export function mockReadApparatus(apparatus: Apparatus) {
  return http.get<{ id: string }>(`**/catalog/equipment/instruments/${apparatus.id}`, () => {
    return HttpResponse.json({ data: toResource(apparatus) });
  });
}

export function mockListApparatuses(apparatuses: Apparatus[] = APPARATUSES) {
  return http.get<{ id: string }>(`**/catalog/equipment/instruments`, () => {
    return HttpResponse.json({ data: apparatuses.map((i) => toResource(i)) });
  });
}

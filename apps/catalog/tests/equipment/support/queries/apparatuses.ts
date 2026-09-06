import { http, HttpResponse } from 'msw';

import { toResource } from '#tests/support/data/resources.ts';

import { BALANCE_BEAM, PARALLEL_BARS, RINGS } from '../fixtures/apparatuses';

import type { Apparatus } from '#equipment';

export function readApparatusMock(apparatus: Apparatus) {
  return http.get<{ id: string }>(`**/catalog/equipment/instruments/${apparatus.id}`, () => {
    return HttpResponse.json(toResource(apparatus));
  });
}

export function readApparatusesMock(
  apparatuses: Apparatus[] = [PARALLEL_BARS, BALANCE_BEAM, RINGS]
) {
  return http.get<{ id: string }>(`**/catalog/equipment/instruments`, () => {
    return HttpResponse.json({ data: apparatuses.map((i) => toResource(i)) });
  });
}

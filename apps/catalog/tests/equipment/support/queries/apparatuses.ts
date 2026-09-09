import { http, HttpResponse } from 'msw';

import { toJsonApiDocument, toJsonApiErrorDocument } from '#tests/support/data/jsonapi.ts';
import { toResource } from '#tests/support/data/resources.ts';

import { APPARATUSES } from '../fixtures/apparatuses';

import type { Apparatus } from '#equipment';
import type { ApiError } from '#tests/support/data/errors.ts';

export function mockReadApparatus(apparatus: Apparatus) {
  return http.get<{ id: string }>(`**/catalog/equipment/apparatuses/${apparatus.id}`, () => {
    return HttpResponse.json(toJsonApiDocument(toResource(apparatus)));
  });
}

export function mockReadApparatusWithError(slug: string, error: ApiError) {
  return http.get<{ id: string }>(`**/catalog/equipment/apparatuses/${slug}`, () => {
    return HttpResponse.json(toJsonApiErrorDocument(error.error), { status: error.status });
  });
}

export function mockListApparatuses(apparatuses: Apparatus[] = APPARATUSES) {
  return http.get(`**/catalog/equipment/apparatuses`, () => {
    return HttpResponse.json({ data: apparatuses.map((i) => toResource(i)) });
  });
}

export function mockListApparatusesWithError(error: ApiError) {
  return http.get(`**/catalog/equipment/apparatuses`, () => {
    return HttpResponse.json(toJsonApiErrorDocument(error.error), { status: error.status });
  });
}

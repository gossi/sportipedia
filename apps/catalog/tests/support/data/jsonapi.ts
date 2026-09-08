import type { JsonApiError } from '#support/data/jsonapi.ts';

export function toJsonApiDocument(data: object | object[]) {
  return { data };
}

export function toJsonApiErrorDocument(errors: JsonApiError | JsonApiError[]) {
  return { errors: Array.isArray(errors) ? errors : [errors] };
}

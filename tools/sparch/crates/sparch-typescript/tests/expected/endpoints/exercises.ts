import { HttpResponse, type RequestHandler, type ResponseResolver } from 'msw';

import { toJsonApiDocument } from '#test-support/data/jsonapi.ts';
import { toResource } from '#test-support/data/resources.ts';
import { type Endpoint, makeJsonResponder, mock } from '#test-support/msw';

import type { Exercise } from '#exercises';

// Utils

export function makeExerciseResponse(exercise: Exercise): ResponseResolver {
  return makeJsonResponder(toJsonApiDocument(toResource(exercise)));
}

// Endpoints

export function makeCreateExerciseEndpoint(): Endpoint {
  return { method: 'POST', path: `**/catalog/exercises/exercises/create-exercise` };
}


export function makeListExercisesEndpoint(): Endpoint {
  return { method: 'GET', path: `**/catalog/exercises/exercises` };
}


// Mocks

export function mockCreateExercise(): RequestHandler {
  return mock(makeCreateExerciseEndpoint(), async ({ request }) => {
    const exercise = (await request.json()) as Exercise;

    return HttpResponse.json(toJsonApiDocument(toResource(exercise)));
  });
}


export function mockListExercises(exercises: Exercise[]): RequestHandler {
  const data = exercises.map((exercise) => toResource(exercise));

  return mock(makeListExercisesEndpoint(), makeJsonResponder(toJsonApiDocument(data)));
}


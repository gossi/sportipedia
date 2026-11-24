/**
 * @module Exercise Actions
 * @mergeModuleWith Exercise
 */
import { cacheKeyFor } from '@warp-drive/core';
import { buildBaseURL } from '@warp-drive/utilities';
import {
  createRecord,
  deleteRecord,
  serializePatch,
  serializeResources,
  updateRecord
} from '@warp-drive/utilities/json-api.cjs';

import type { Exercise, ExerciseFields } from './exercise';
import type { ReactiveResource } from '@warp-drive/core/reactive';
import type {
  CreateRequestOptions,
  DeleteRequestOptions,
  UpdateRequestOptions
} from '@warp-drive/core/types/request';
import type { WithPartial } from '@warp-drive/core/types/utils';
import type { Store } from '#support/data';


type CreateExerciseData = WithPartial<ExerciseFields, 'difficulty'>;

/**
 * @group Exercise
 * @category Actions
 */
export function createExercise(
  data: CreateExerciseData,
  { store }: { store: Store }
): CreateRequestOptions<Exercise> {
  const exercise = store.createRecord<Exercise>('exercise', data);
  const options = createRecord(exercise, {
    resourcePath: 'exercises/exercises/create-exercise',
    reload: true
  });

  options.headers.append('Content-Type', 'application/vnd.api+json');
  options.body = JSON.stringify({
    data: store.cache.peek(cacheKeyFor(exercise))
  });

  return options;
}


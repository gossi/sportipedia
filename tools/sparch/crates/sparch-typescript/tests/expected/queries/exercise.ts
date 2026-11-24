/**
 * @module Exercise Queries
 * @mergeModuleWith Exercise
 */
import { findRecord, query } from '@warp-drive/utilities/json-api';

import type { Exercise } from './exercise';
import type { ReactiveDataDocument } from '@warp-drive/core/reactive';
import type { FindRecordOptions } from '@warp-drive/core/types';
import type { QueryParamsSource } from '@warp-drive/core/types/params';
import type { FindRecordRequestOptions, QueryRequestOptions } from '@warp-drive/core/types/request';
/**
 * @group Exercise
 * @category Queries
 */
export function listExercises(
  params: QueryParamsSource = {}
): QueryRequestOptions<ReactiveDataDocument<Exercise[]>> {
  return query<Exercise>('exercise', params, { resourcePath: 'exercises/exercises' });
}


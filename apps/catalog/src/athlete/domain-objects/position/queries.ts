/**
 * @module Position Queries
 * @mergeModuleWith Position
 */
import { findRecord, query } from '@warp-drive/utilities/json-api';

import type { Position } from './position';
import type { ReactiveDataDocument } from '@warp-drive/core/reactive';
import type { FindRecordOptions } from '@warp-drive/core/types';
import type { QueryParamsSource } from '@warp-drive/core/types/params';
import type { FindRecordRequestOptions, QueryRequestOptions } from '@warp-drive/core/types/request';

/**
 * @group Position
 * @category Queries
 */
export function readPositiones(
  params: QueryParamsSource = {}
): QueryRequestOptions<ReactiveDataDocument<Position[]>> {
  return query<Position>('position', params, { resourcePath: 'athlete/positions' });
}

/**
 * @group Position
 * @category Queries
 */
export function readPosition(
  idOrSlug: string,
  params: FindRecordOptions = {}
): FindRecordRequestOptions<ReactiveDataDocument<Position>, Position> {
  return findRecord<Position>('position', idOrSlug, {
    resourcePath: 'athlete/positions',
    ...params
  });
}

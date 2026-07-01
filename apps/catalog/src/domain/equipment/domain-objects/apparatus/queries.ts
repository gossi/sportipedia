import { findRecord, query } from '@warp-drive/utilities/json-api';

import type { Apparatus } from './apparatus.ts';
import type { ReactiveDataDocument } from '@warp-drive/core/reactive';
import type { FindRecordOptions } from '@warp-drive/core/types';
import type { QueryParamsSource } from '@warp-drive/core/types/params';
import type { FindRecordRequestOptions, QueryRequestOptions } from '@warp-drive/core/types/request';

export function readApparatuses(
  params: QueryParamsSource = {}
): QueryRequestOptions<ReactiveDataDocument<Apparatus[]>> {
  return query<Apparatus>('apparatuses', params, { resourcePath: 'equipment/apparatuses' });
}

export function readApparatus(
  idOrSlug: string,
  params: FindRecordOptions = {}
): FindRecordRequestOptions<ReactiveDataDocument<Apparatus>, Apparatus> {
  return findRecord<Apparatus>('apparatuses', idOrSlug, {
    resourcePath: 'equipment/apparatuses',
    ...params
  });
}

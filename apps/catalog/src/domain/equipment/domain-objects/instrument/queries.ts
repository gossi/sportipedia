import { findRecord, query } from '@warp-drive/utilities/json-api';

import type { Instrument } from './instrument';
import type { ReactiveDataDocument } from '@warp-drive/core/reactive';
import type { FindRecordOptions } from '@warp-drive/core/types';
import type { QueryParamsSource } from '@warp-drive/core/types/params';
import type { FindRecordRequestOptions, QueryRequestOptions } from '@warp-drive/core/types/request';

export function readInstruments(
  params: QueryParamsSource = {}
): QueryRequestOptions<ReactiveDataDocument<Instrument[]>> {
  return query<Instrument>('instruments', params, { resourcePath: 'equipment/instruments' });
}

export function readInstrument(
  idOrSlug: string,
  params: FindRecordOptions = {}
): FindRecordRequestOptions<ReactiveDataDocument<Instrument>, Instrument> {
  return findRecord<Instrument>('instruments', idOrSlug, {
    resourcePath: 'equipment/instruments',
    ...params
  });
}

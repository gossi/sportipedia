/**
 * @module Instrument Queries
 * @mergeModuleWith Instrument
 */
import { findRecord, query } from '@warp-drive/utilities/json-api';

import type { Instrument } from './instrument';
import type { ReactiveDataDocument } from '@warp-drive/core/reactive';
import type { FindRecordOptions } from '@warp-drive/core/types';
import type { QueryParamsSource } from '@warp-drive/core/types/params';
import type { FindRecordRequestOptions, QueryRequestOptions } from '@warp-drive/core/types/request';

/**
 * @group Instrument
 * @category Queries
 */
export function readInstruments(
  params: QueryParamsSource = {}
): QueryRequestOptions<ReactiveDataDocument<Instrument[]>> {
  return query<Instrument>('instrument', params, { resourcePath: 'equipment/instruments' });
}

/**
 * @group Instrument
 * @category Queries
 */
export function readInstrument(
  idOrSlug: string,
  params: FindRecordOptions = {}
): FindRecordRequestOptions<ReactiveDataDocument<Instrument>, Instrument> {
  return findRecord<Instrument>('instrument', idOrSlug, {
    resourcePath: 'equipment/instruments',
    ...params
  });
}

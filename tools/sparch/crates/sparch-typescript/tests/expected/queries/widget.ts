/**
 * @module Widget Queries
 * @mergeModuleWith Widget
 */
import { findRecord, query } from '@warp-drive/utilities/json-api';

import type { Widget } from './widget';
import type { ReactiveDataDocument } from '@warp-drive/core/reactive';
import type { FindRecordOptions } from '@warp-drive/core/types';
import type { QueryParamsSource } from '@warp-drive/core/types/params';
import type { FindRecordRequestOptions, QueryRequestOptions } from '@warp-drive/core/types/request';
/**
 * @group Widget
 * @category Queries
 */
export function listWidgets(
  params: QueryParamsSource = {}
): QueryRequestOptions<ReactiveDataDocument<Widget[]>> {
  return query<Widget>('widget', params, { resourcePath: 'equipment/widgets' });
}

/**
 * @group Widget
 * @category Queries
 */
export function readWidget(
  idOrSlug: string,
  params: FindRecordOptions = {}
): FindRecordRequestOptions<ReactiveDataDocument<Widget>, Widget> {
  return findRecord<Widget>('widget', idOrSlug, {
    resourcePath: 'equipment/widgets',
    ...params
  });
}


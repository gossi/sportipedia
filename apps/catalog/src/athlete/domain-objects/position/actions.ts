/**
 * @module Position Actions
 * @mergeModuleWith Position
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

import type { Position, PositionFields } from './position';
import type { ReactiveResource } from '@warp-drive/core/reactive';
import type {
  CreateRequestOptions,
  DeleteRequestOptions,
  UpdateRequestOptions
} from '@warp-drive/core/types/request';
import type { WithPartial } from '@warp-drive/core/types/utils';
import type { Store } from '#support/data';

type CatalogPositionData = WithPartial<PositionFields, 'description'>;

/**
 * @group Position
 * @category Actions
 */
export function catalogPosition(
  data: CatalogPositionData,
  { store }: { store: Store }
): CreateRequestOptions<Position> {
  const position = store.createRecord<Position>('position', data);
  const options = createRecord(position, {
    resourcePath: 'athlete/position/catalog-position',
    reload: true
  });

  options.headers.append('Content-Type', 'application/vnd.api+json');
  options.body = JSON.stringify({
    data: store.cache.peek(cacheKeyFor(position))
  });

  return options;
}

/**
 * @group Position
 * @category Actions
 */
export function editPosition(
  record: ReactiveResource,
  changes: Position,
  { store }: { store: Store }
): UpdateRequestOptions {
  Object.assign(record, changes);

  const requestOptions = updateRecord(record, {
    reload: true
  });

  // @ts-expect-error warp-drive thinks, this must be PUT or PATCH (haiyaa, so wrong!)
  requestOptions.method = 'POST';
  requestOptions.url = buildBaseURL({ resourcePath: 'athlete/position/edit-apparatus' });
  requestOptions.headers.append('Content-Type', 'application/vnd.api+json');

  const payload = serializePatch(store.cache, cacheKeyFor(record));

  // payload.data.attributes = data;
  requestOptions.body = JSON.stringify(payload);

  return requestOptions;
}

/**
 * @group Position
 * @category Actions
 */
export function archivePosition(
  record: ReactiveResource,
  { store }: { store: Store }
): DeleteRequestOptions<ReactiveResource> {
  const requestOptions = deleteRecord(record);

  // @ts-expect-error warp-drive thinks, this must be DELETE (haiyaa, so wrong!)
  requestOptions.method = 'POST';
  requestOptions.url = buildBaseURL({ resourcePath: 'athlete/position/archive-apparatus' });
  requestOptions.headers.append('Content-Type', 'application/vnd.api+json');

  const payload = serializeResources(store.cache, cacheKeyFor(record));

  requestOptions.body = JSON.stringify(payload);

  return requestOptions;
}

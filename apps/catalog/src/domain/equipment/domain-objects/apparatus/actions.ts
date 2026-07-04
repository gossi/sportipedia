import { cacheKeyFor } from '@warp-drive/core';
import { buildBaseURL } from '@warp-drive/utilities';
import {
  createRecord,
  deleteRecord,
  serializePatch,
  serializeResources,
  updateRecord
} from '@warp-drive/utilities/json-api';

import type { Apparatus } from './apparatus';
import type { ReactiveResource } from '@warp-drive/core/reactive';
import type {
  CreateRequestOptions,
  DeleteRequestOptions,
  UpdateRequestOptions
} from '@warp-drive/core/types/request';
import type Store from '#/services/store';

type CatalogApparatusData = Omit<Apparatus, 'ID'>;

export function catalogApparatus(
  data: CatalogApparatusData,
  { store }: { store: Store }
): CreateRequestOptions<Apparatus> {
  const apparatus = store.createRecord<Apparatus>('apparatuses', data);
  const options = createRecord(apparatus, {
    resourcePath: 'equipment/apparatuses/catalog-apparatus',
    reload: true
  });

  options.headers.append('Content-Type', 'application/vnd.api+json');
  options.body = JSON.stringify({
    data: store.cache.peek(cacheKeyFor(apparatus))
  });

  return options;
}

export function editApparatus(
  record: ReactiveResource,
  changes: Apparatus,
  { store }: { store: Store }
): UpdateRequestOptions {
  Object.assign(record, changes);

  const requestOptions = updateRecord(record, {
    reload: true
  });

  // @ts-expect-error warp-drive thinks, this must be PUT or PATCH (haiyaa, so wrong!)
  requestOptions.method = 'POST';
  requestOptions.url = buildBaseURL({ resourcePath: 'equipment/apparatuses/edit-apparatus' });
  requestOptions.headers.append('Content-Type', 'application/vnd.api+json');

  const payload = serializePatch(store.cache, cacheKeyFor(record));

  // payload.data.attributes = data;
  requestOptions.body = JSON.stringify(payload);

  return requestOptions;
}

export function archiveApparatus(
  record: ReactiveResource,
  { store }: { store: Store }
): DeleteRequestOptions<ReactiveResource> {
  const requestOptions = deleteRecord(record);

  // @ts-expect-error warp-drive thinks, this must be DELETE (haiyaa, so wrong!)
  requestOptions.method = 'POST';
  requestOptions.url = buildBaseURL({ resourcePath: 'equipment/apparatuses/archive-apparatus' });
  requestOptions.headers.append('Content-Type', 'application/vnd.api+json');

  const payload = serializeResources(store.cache, cacheKeyFor(record));

  requestOptions.body = JSON.stringify(payload);

  return requestOptions;
}

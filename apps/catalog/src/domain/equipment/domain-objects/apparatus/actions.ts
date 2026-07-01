import { cacheKeyFor } from '@warp-drive/core';
import { checkout, type ReactiveResource } from '@warp-drive/core/reactive';
import { buildBaseURL } from '@warp-drive/utilities';
import { createRecord, serializePatch, updateRecord } from '@warp-drive/utilities/json-api';

import type { Apparatus } from './apparatus';
import type Store from '#/services/store';

type CatalogApparatusData = Omit<Apparatus, 'ID'>;

export async function catalogApparatus(data: CatalogApparatusData, { store }: { store: Store }) {
  const apparatus = store.createRecord('apparatuses', data);
  const options = createRecord(apparatus, {
    resourcePath: 'equipment/apparatuses/catalog-apparatus',
    reload: true
  });

  options.headers.append('Content-Type', 'application/vnd.api+json');
  options.body = JSON.stringify({
    data: store.cache.peek(cacheKeyFor(apparatus))
  });

  return await store.request({
    ...options,
    cacheOptions: {
      types: ['apparatuses']
    }
  });
}

export async function editApparatus(
  record: ReactiveResource,
  changes: Apparatus,
  { store }: { store: Store }
) {
  const mutable = await checkout(record);

  Object.assign(mutable, changes);

  const requestOptions = updateRecord(mutable, {
    reload: true
  });

  // @ts-expect-error warp-drive thinks, this must be PUT or PATCH (so wrong!)
  requestOptions.method = 'POST';
  requestOptions.url = buildBaseURL({ resourcePath: 'equipment/apparatuses/edit-apparatus' });
  requestOptions.headers.append('Content-Type', 'application/vnd.api+json');

  const payload = serializePatch(store.cache, cacheKeyFor(mutable));

  // payload.data.attributes = data;
  requestOptions.body = JSON.stringify(payload);

  return await store.request({
    ...requestOptions,
    cacheOptions: {
      types: ['apparatuses']
    }
  });
}

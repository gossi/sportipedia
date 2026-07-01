import { cacheKeyFor } from '@warp-drive/core';
import { checkout, type ReactiveResource } from '@warp-drive/core/reactive';
import { buildBaseURL } from '@warp-drive/utilities';
import { createRecord, serializePatch, updateRecord } from '@warp-drive/utilities/json-api';

import type { Instrument } from './instrument';
import type Store from '#/services/store';

type CatalogInstrumentData = Omit<Instrument, 'ID'>;

export async function catalogInstrument(data: CatalogInstrumentData, { store }: { store: Store }) {
  const person = store.createRecord('instruments', data);
  const options = createRecord(person, {
    resourcePath: 'equipment/instruments/catalog-instrument',
    reload: true
  });

  options.headers.append('Content-Type', 'application/vnd.api+json');
  options.body = JSON.stringify({
    data: store.cache.peek(cacheKeyFor(person))
  });

  return await store.request({
    ...options,
    cacheOptions: {
      types: ['instruments']
    }
  });
}

export async function editInstrument(
  record: ReactiveResource,
  changes: Instrument,
  { store }: { store: Store }
) {
  const mutable = await checkout(record);

  Object.assign(mutable, changes);

  const requestOptions = updateRecord(mutable, {
    reload: true
  });

  // @ts-expect-error warp-drive thinks, this must be PUT or PATCH (so wrong!)
  requestOptions.method = 'POST';
  requestOptions.url = buildBaseURL({ resourcePath: 'equipment/instruments/edit-instrument' });
  requestOptions.headers.append('Content-Type', 'application/vnd.api+json');

  const payload = serializePatch(store.cache, cacheKeyFor(mutable));

  // payload.data.attributes = data;
  requestOptions.body = JSON.stringify(payload);

  return await store.request({
    ...requestOptions,
    cacheOptions: {
      types: ['instruments']
    }
  });
}

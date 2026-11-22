/**
 * @module Instrument Actions
 * @mergeModuleWith Instrument
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

import type { Instrument, InstrumentFields } from './instrument';
import type { ReactiveResource } from '@warp-drive/core/reactive';
import type {
  CreateRequestOptions,
  DeleteRequestOptions,
  UpdateRequestOptions
} from '@warp-drive/core/types/request';
import type { WithPartial } from '@warp-drive/core/types/utils';
import type { Store } from '#support/data';

/**
 * @group Instrument
 * @category Actions
 */
export function archiveInstrument(
  record: ReactiveResource,
  { store }: { store: Store }
): DeleteRequestOptions<ReactiveResource> {
  const requestOptions = deleteRecord(record);

  // @ts-expect-error warp-drive thinks, this must be DELETE (haiyaa, so wrong!)
  requestOptions.method = 'POST';
  requestOptions.url = buildBaseURL({ resourcePath: 'equipment/instruments/archive-instrument' });
  requestOptions.headers.append('Content-Type', 'application/vnd.api+json');

  const payload = serializeResources(store.cache, cacheKeyFor(record));

  requestOptions.body = JSON.stringify(payload);

  return requestOptions;
}


type CatalogInstrumentData = WithPartial<InstrumentFields, 'description'>;

/**
 * @group Instrument
 * @category Actions
 */
export function catalogInstrument(
  data: CatalogInstrumentData,
  { store }: { store: Store }
): CreateRequestOptions<Instrument> {
  const instrument = store.createRecord<Instrument>('instrument', data);
  const options = createRecord(instrument, {
    resourcePath: 'equipment/instruments/catalog-instrument',
    reload: true
  });

  options.headers.append('Content-Type', 'application/vnd.api+json');
  options.body = JSON.stringify({
    data: store.cache.peek(cacheKeyFor(instrument))
  });

  return options;
}


type EditInstrumentData = Partial<InstrumentFields>;

/**
 * @group Instrument
 * @category Actions
 */
export function editInstrument(
  record: ReactiveResource,
  changes: EditInstrumentData,
  { store }: { store: Store }
): UpdateRequestOptions {
  Object.assign(record, changes);

  const requestOptions = updateRecord(record, {
    reload: true
  });

  // @ts-expect-error warp-drive thinks, this must be PUT or PATCH (haiyaa, so wrong!)
  requestOptions.method = 'POST';
  requestOptions.url = buildBaseURL({ resourcePath: 'equipment/instruments/edit-instrument' });
  requestOptions.headers.append('Content-Type', 'application/vnd.api+json');

  const payload = serializePatch(store.cache, cacheKeyFor(record));

  requestOptions.body = JSON.stringify(payload);

  return requestOptions;
}


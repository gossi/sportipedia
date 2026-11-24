/**
 * @module Widget Actions
 * @mergeModuleWith Widget
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

import type { Widget, WidgetFields } from './widget';
import type { ReactiveResource } from '@warp-drive/core/reactive';
import type {
  CreateRequestOptions,
  DeleteRequestOptions,
  UpdateRequestOptions
} from '@warp-drive/core/types/request';
import type { WithPartial } from '@warp-drive/core/types/utils';
import type { Store } from '#support/data';

/**
 * @group Widget
 * @category Actions
 */
export function archiveWidget(
  record: ReactiveResource,
  { store }: { store: Store }
): DeleteRequestOptions<ReactiveResource> {
  const requestOptions = deleteRecord(record);

  // @ts-expect-error warp-drive thinks, this must be DELETE (haiyaa, so wrong!)
  requestOptions.method = 'POST';
  requestOptions.url = buildBaseURL({ resourcePath: 'equipment/widgets/archive-widget' });
  requestOptions.headers.append('Content-Type', 'application/vnd.api+json');

  const payload = serializeResources(store.cache, cacheKeyFor(record));

  requestOptions.body = JSON.stringify(payload);

  return requestOptions;
}


type CreateWidgetData = WithPartial<WidgetFields, 'coachId' | 'description' | 'label' | 'teamId'>;

/**
 * @group Widget
 * @category Actions
 */
export function createWidget(
  data: CreateWidgetData,
  { store }: { store: Store }
): CreateRequestOptions<Widget> {
  const widget = store.createRecord<Widget>('widget', data);
  const options = createRecord(widget, {
    resourcePath: 'equipment/widgets/create-widget',
    reload: true
  });

  options.headers.append('Content-Type', 'application/vnd.api+json');
  options.body = JSON.stringify({
    data: store.cache.peek(cacheKeyFor(widget))
  });

  return options;
}


type EditWidgetData = Partial<WidgetFields>;

/**
 * @group Widget
 * @category Actions
 */
export function editWidget(
  record: ReactiveResource,
  changes: EditWidgetData,
  { store }: { store: Store }
): UpdateRequestOptions {
  Object.assign(record, changes);

  const requestOptions = updateRecord(record, {
    reload: true
  });

  // @ts-expect-error warp-drive thinks, this must be PUT or PATCH (haiyaa, so wrong!)
  requestOptions.method = 'POST';
  requestOptions.url = buildBaseURL({ resourcePath: 'equipment/widgets/edit-widget' });
  requestOptions.headers.append('Content-Type', 'application/vnd.api+json');

  const payload = serializePatch(store.cache, cacheKeyFor(record));

  requestOptions.body = JSON.stringify(payload);

  return requestOptions;
}


type NoteWidgetData = Partial<WidgetFields>;

/**
 * @group Widget
 * @category Actions
 */
export function noteWidget(
  record: ReactiveResource,
  changes: NoteWidgetData,
  { store }: { store: Store }
): UpdateRequestOptions {
  Object.assign(record, changes);

  const requestOptions = updateRecord(record, {
    reload: true
  });

  // @ts-expect-error warp-drive thinks, this must be PUT or PATCH (haiyaa, so wrong!)
  requestOptions.method = 'POST';
  requestOptions.url = buildBaseURL({ resourcePath: 'equipment/widgets/note-widget' });
  requestOptions.headers.append('Content-Type', 'application/vnd.api+json');

  const payload = serializePatch(store.cache, cacheKeyFor(record));

  requestOptions.body = JSON.stringify(payload);

  return requestOptions;
}


type RelabelWidgetData = Partial<WidgetFields>;

/**
 * @group Widget
 * @category Actions
 */
export function relabelWidget(
  record: ReactiveResource,
  changes: RelabelWidgetData,
  { store }: { store: Store }
): UpdateRequestOptions {
  Object.assign(record, changes);

  const requestOptions = updateRecord(record, {
    reload: true
  });

  // @ts-expect-error warp-drive thinks, this must be PUT or PATCH (haiyaa, so wrong!)
  requestOptions.method = 'POST';
  requestOptions.url = buildBaseURL({ resourcePath: 'equipment/widgets/relabel-widget' });
  requestOptions.headers.append('Content-Type', 'application/vnd.api+json');

  const payload = serializePatch(store.cache, cacheKeyFor(record));

  requestOptions.body = JSON.stringify(payload);

  return requestOptions;
}


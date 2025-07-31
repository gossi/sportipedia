import { CacheHandler, Fetch, RequestManager, Store as DataStore } from '@warp-drive/core';
import {
  instantiateRecord,
  registerDerivations,
  SchemaService,
  teardownRecord
} from '@warp-drive/core/reactive';
import { DefaultCachePolicy } from '@warp-drive/core/store';

// import { JSONAPICache } from '@warp-drive/json-api';
import type { CacheCapabilitiesManager } from '@warp-drive/core/types';
import type { Cache } from '@warp-drive/core/types/cache';
import type { ResourceKey } from '@warp-drive/core/types/identifier';

export default class Store extends DataStore {
  // constructor(args: unknown) {
  //   super(args);

  //   const manager = (this.requestManager = new RequestManager());

  //   manager.use([Fetch]);
  //   manager.useCache(CacheHandler);
  // }

  requestManager = new RequestManager().use([Fetch]);
  // .useCache(CacheHandler)

  lifetimes = new DefaultCachePolicy({
    apiCacheHardExpires: 15 * 60 * 1000, // 15 minutes
    apiCacheSoftExpires: 1 * 30 * 1000, // 30 seconds
    constraints: {
      headers: {
        'X-WarpDrive-Expires': true,
        'Cache-Control': true,
        Expires: true
      }
    }
  });

  createSchemaService() {
    const schema = new SchemaService();

    registerDerivations(schema);

    return schema;
  }

  // createCache(capabilities: CacheCapabilitiesManager): Cache {
  //   return new JSONAPICache(capabilities);
  // }

  instantiateRecord(identifier: ResourceKey, createArgs?: Record<string, unknown>) {
    return instantiateRecord(this, identifier, createArgs);
  }

  teardownRecord(record: unknown): void {
    teardownRecord(record);
  }
}

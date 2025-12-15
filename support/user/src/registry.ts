import { buildRegistry } from 'ember-strict-application-resolver/build-registry';

import { AuthService } from './services/auth.ts';

export const userRegistry: (namespace?: string) => Record<string, unknown> = buildRegistry({
  './services/auth': { default: AuthService }
});

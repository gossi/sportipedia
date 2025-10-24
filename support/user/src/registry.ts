import { buildRegistry } from 'ember-strict-application-resolver/build-registry';

import { AuthService } from './services/auth.ts';

export const userRegistry = buildRegistry({
  './services/auth': { default: AuthService }
});

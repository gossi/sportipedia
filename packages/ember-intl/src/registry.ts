import { buildRegistry } from 'ember-strict-application-resolver/build-registry';

import { IntlService } from './services/intl.ts';

export const intlRegistry = buildRegistry({
  './services/intl': { default: IntlService }
});

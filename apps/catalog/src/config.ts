import { setBuildURLConfig } from '@warp-drive/utilities';
import translations from 'virtual:ember-intl-loader';

import { auth } from '#auth/client';
import { configureEquipmentSchema } from '#equipment';

import type ApplicationInstance from '@ember/application/instance';
import type Store from '#/services/store';

function configureAuth(app: ApplicationInstance) {
  const authService = app.lookup('service:auth');
  const router = app.lookup('service:router');

  authService.setup(auth);
  authService.subscribe('sessionInvalidated', () => {
    router.transitionTo('application');
  });
}

function configureIntl(app: ApplicationInstance) {
  const intl = app.lookup('service:intl');

  intl.setLocale('de');

  for (const [locale, messages] of Object.entries(translations)) {
    // eslint-disable-next-line @typescript-eslint/no-unsafe-argument
    intl.addTranslations(locale, messages);
  }
}

function configureApi(app: ApplicationInstance) {
  setBuildURLConfig({
    host: __API_URL__,
    namespace: 'catalog'
  });

  const store = app.lookup('service:store') as Store;

  configureEquipmentSchema(store.schema);
}

export function configure(app: ApplicationInstance) {
  configureAuth(app);
  configureIntl(app);
  configureApi(app);
}

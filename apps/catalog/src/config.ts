import translations from 'virtual:ember-intl-loader';

import { auth } from './auth';

import type ApplicationInstance from '@ember/application/instance';

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

export function configure(app: ApplicationInstance) {
  configureAuth(app);
  configureIntl(app);
}

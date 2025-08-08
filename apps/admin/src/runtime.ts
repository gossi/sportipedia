import { SportipediaOauthAuthenticator } from '@sportipedia/auth';
import translations from 'virtual:ember-intl-loader';

import type ApplicationInstance from '@ember/application/instance';
import type { SessionService } from 'ember-auth';
import type { IntlService } from 'ember-intl';

function configureAuth(app: ApplicationInstance) {
  const session = app.lookup('service:session') as SessionService;

  session.registerAuthenticator(
    new SportipediaOauthAuthenticator({
      name: 'oauth'
    })
  );
}

function configureIntl(app: ApplicationInstance) {
  const intl = app.lookup('service:intl') as IntlService;

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

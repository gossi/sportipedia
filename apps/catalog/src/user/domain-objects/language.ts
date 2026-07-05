import { auth } from '#auth/client';

import type { IntlService } from 'ember-intl';

export async function persistLanguage(locale: string) {
  return await auth.updateUser({
    // @ts-expect-error better-auth doesn't work with custom fields
    lang: locale
  });
}

export function renderLocale(locale: string) {
  const languageNames = new Intl.DisplayNames(locale, { type: 'language' });

  return languageNames.of(locale);
}

export async function changeLocale(locale: string, { intl }: { intl: IntlService }) {
  intl.setLocale(locale);

  return await persistLanguage(locale);
}

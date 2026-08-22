/**
 * @module Language
 * @category Domain Objects
 */
import { auth } from '#auth/client';

import type { IntlService } from 'ember-intl';

/**
 * @group Language
 * @category Language
 */
export async function persistLanguage(locale: string) {
  return await auth.updateUser({
    // @ts-expect-error better-auth doesn't work with custom fields
    lang: locale
  });
}

/**
 * @group Language
 * @category Language
 */
export function renderLocale(locale: string) {
  const languageNames = new Intl.DisplayNames(locale, { type: 'language' });

  return languageNames.of(locale);
}

/**
 * @group Language
 * @category Language
 */
export async function changeLocale(locale: string, { intl }: { intl: IntlService }) {
  intl.setLocale(locale);

  return await persistLanguage(locale);
}

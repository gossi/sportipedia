export function convertToArray(locale: string | string[]): string[] {
  if (Array.isArray(locale)) {
    return locale;
  }

  return [locale];
}

export function convertToString(locale: string | string[]): string {
  if (Array.isArray(locale)) {
    return locale[0] as string;
  }

  return locale;
}

export function normalizeLocale(locale: string): string {
  return locale.replaceAll('_', '-').toLowerCase();
}

type MaybeLocale = string[] | string | null | undefined;

export function hasLocaleChanged(locale1: string[], locale2: MaybeLocale): boolean {
  if (!Array.isArray(locale2)) {
    return true;
  }

  return locale1.toString() !== locale2.toString();
}

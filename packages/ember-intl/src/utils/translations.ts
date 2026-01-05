type IndexSignatureParameter = string | number | symbol;

type NestedStructure<T extends IndexSignatureParameter> = {
  [Key in IndexSignatureParameter]?: T | NestedStructure<T>;
};

export type Translations = NestedStructure<string>;

/**
 * @private
 * @hide
 */
export function flattenKeys<T extends IndexSignatureParameter>(
  object: NestedStructure<T>
): Record<string, T> {
  const result = {} as Record<string, T>;

  for (const key in object) {
    if (!Object.prototype.hasOwnProperty.call(object, key)) {
      continue;
    }

    const value = object[key];

    // If `value` is not `null`
    if (value && typeof value === 'object') {
      const hash = flattenKeys(value);

      for (const suffix in hash) {
        const translation = hash[suffix];

        if (translation !== undefined) {
          result[`${key}.${suffix}`] = translation;
        }
      }
    } else {
      if (value !== undefined) {
        result[key] = value;
      }
    }
  }

  return result;
}

export type MissingTranslationHandler = (
  key: string,
  locales: string[],
  options?: Record<string, unknown>
) => string;

export const handleMissingTranslation: MissingTranslationHandler = (key, locales) => {
  const locale = locales.join(', ');

  return `Missing translation "${key}" for locale "${locale}"`;
};

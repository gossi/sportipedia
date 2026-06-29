import { tracked } from '@glimmer/tracking';
import { next } from '@ember/runloop';
import Service from '@ember/service';
import { htmlSafe } from '@ember/template';

import { createIntl, createIntlCache, type IntlShape } from '@formatjs/intl';

import { formatMessage, type FormatMessageParameters } from '../formatters';
import { escapeFormatMessageOptions } from '../utils/escaping';
import {
  convertToArray,
  convertToString,
  hasLocaleChanged,
  normalizeLocale
} from '../utils/locale';
import {
  flattenKeys,
  handleMissingTranslation,
  type MissingTranslationHandler,
  type Translations
} from '../utils/translations';

export class IntlService extends Service {
  @tracked private _intls: Record<string, IntlShape> = {};
  @tracked private _locale: string[] = [];

  #cache = createIntlCache();
  #missingTranslationHandler: MissingTranslationHandler = handleMissingTranslation;

  // private _timer?: EmberRunTimer;

  get locales(): string[] {
    return Object.keys(this._intls);
  }

  get primaryLocale(): string | undefined {
    if (this._locale.length === 0) {
      return;
    }

    return this._locale[0];
  }

  // constructor() {
  //   // eslint-disable-next-line prefer-rest-params
  //   super(...arguments);

  //   const hasNewConfiguration = Boolean(
  //     // @ts-expect-error: Property 'resolveRegistration' does not exist on type 'Owner'
  //     // eslint-disable-next-line @typescript-eslint/no-unsafe-call
  //     getOwner(this).resolveRegistration('ember-intl:main')
  //   );

  //   if (!hasNewConfiguration) {
  //     this.getDefaultFormats();
  //   }

  //   // Hydrate
  //   translations.forEach(([locale, translations]: [string, Translations]) => {
  //     this.addTranslations(locale, translations);
  //   });
  // }

  addTranslations(locale: string, translations: Translations) {
    const messages = flattenKeys(translations);

    this.updateIntl(locale, messages);
  }

  private createIntl(locale: string | string[], messages: Record<string, unknown> = {}): IntlShape {
    const resolvedLocale = convertToString(locale);
    // const formats = this._formats;

    return createIntl(
      {
        // defaultFormats: formats,
        defaultLocale: resolvedLocale,
        // formats,
        locale: resolvedLocale,
        // @ts-expect-error: Type 'Record<string, unknown>' is not assignable
        messages
        // onError: this._onFormatjsError
      },
      this.#cache
    );
  }

  exists(key: string, locale?: string | string[]): boolean {
    const locales = locale ? convertToArray(locale) : this._locale;

    return locales.some((l) => {
      return this.getTranslation(key, l) !== undefined;
    });
  }

  private getIntl(locale: string | string[]): IntlShape {
    const resolvedLocale = normalizeLocale(convertToString(locale));

    return this._intls[resolvedLocale] as IntlShape;
  }

  private getIntlShape(locale?: string): IntlShape {
    if (locale) {
      return this.createIntl(locale);
    }

    return this.getIntl(this._locale);
  }

  getTranslation(key: string, locale: string): string | undefined {
    const messages = this.getIntl(locale).messages;

    // if (!messages) {
    //   return;
    // }

    return messages[key] as string | undefined;
  }

  // setFormats(formats: Formats): void {
  //   this._formats = convertToFormatjsFormats(formats);

  //   // Call `updateIntl` to update `formats` for each locale
  //   for (const locale of this.locales) {
  //     this.updateIntl(locale, {});
  //   }
  // }

  setLocale(locale: string | string[]): void {
    const proposedLocale = convertToArray(locale);

    if (hasLocaleChanged(proposedLocale, this._locale)) {
      this._locale = proposedLocale;

      // // eslint-disable-next-line ember/no-runloop
      // cancel(this._timer);

      // // eslint-disable-next-line ember/no-runloop
      // this._timer = next(() => {
      //   this.updateDocumentLanguage();
      // });

      // eslint-disable-next-line ember/no-runloop
      next(() => {
        this.updateDocumentLanguage();
      });
    }

    this.updateIntl(proposedLocale);
  }

  // setOnFormatjsError(onFormatjsError: OnFormatjsError): void {
  //   this._onFormatjsError = onFormatjsError;

  //   // Call `updateIntl` to update `onError` for each locale
  //   for (const locale of this.locales) {
  //     this.updateIntl(locale, {});
  //   }
  // }

  setMissingTranslationHandler(missingTranslationHandler: MissingTranslationHandler): void {
    this.#missingTranslationHandler = missingTranslationHandler;
  }

  t(
    key: string,
    options?: FormatMessageParameters[1] & {
      htmlSafe?: boolean;
      locale?: string;
    }
  ): string {
    const locales = options?.locale ? [options.locale] : this._locale;
    let translation: string | undefined;

    for (const locale of locales) {
      translation = this.getTranslation(key, locale);

      if (translation !== undefined) {
        break;
      }
    }

    if (translation === undefined) {
      return this.#missingTranslationHandler(key, locales, options);
    }

    // Bypass @formatjs/intl
    if (translation === '') {
      return '';
    }

    return this.formatMessage(
      {
        defaultMessage: translation,
        id: key
      },
      options
    );
  }

  formatMessage(
    value: FormatMessageParameters[0] | string | undefined | null,
    options?: FormatMessageParameters[1] & {
      htmlSafe?: boolean;
      locale?: string;
    }
  ): string {
    if (value === undefined || value === null) {
      return '';
    }

    const intlShape = this.getIntlShape(options?.locale);

    const descriptor =
      typeof value === 'object'
        ? value
        : {
            defaultMessage: value,
            description: undefined,
            id: value
          };

    if (options?.htmlSafe) {
      const output = formatMessage(intlShape, descriptor, escapeFormatMessageOptions(options));

      return htmlSafe(output) as unknown as string;
    }

    return formatMessage(intlShape, descriptor, options);
  }

  formatNumber(value: number, options?: Intl.NumberFormatOptions) {
    // eslint-disable-next-line unicorn/no-unreadable-new-expression
    return new Intl.NumberFormat(this._locale, options).format(value);
  }

  formatDuration(value: Intl.DurationInput, options?: Intl.DurationFormatOptions) {
    // eslint-disable-next-line unicorn/no-unreadable-new-expression
    return new Intl.DurationFormat(this._locale, options).format(value);
  }

  formatDateTime(value: Date | number, options?: Intl.DateTimeFormatOptions) {
    // eslint-disable-next-line unicorn/no-unreadable-new-expression
    return new Intl.DateTimeFormat(this._locale, options).format(value);
  }

  formatRelativeTime(
    value: number,
    unit: Intl.RelativeTimeFormatUnit,
    options?: Intl.RelativeTimeFormatOptions
  ) {
    // eslint-disable-next-line unicorn/no-unreadable-new-expression
    return new Intl.RelativeTimeFormat(this._locale, options).format(value, unit);
  }

  private updateDocumentLanguage(): void {
    const html = document.documentElement;

    html.setAttribute('lang', this.primaryLocale as string);
  }

  private updateIntl(locale: string | string[], messages?: Record<string, unknown>): void {
    const resolvedLocale = normalizeLocale(convertToString(locale));
    const intl = this._intls[resolvedLocale];

    let newIntl;

    if (!intl) {
      newIntl = this.createIntl(resolvedLocale, messages);
    } else if (messages) {
      newIntl = this.createIntl(resolvedLocale, {
        ...intl.messages,
        ...messages
      });
    }

    if (!newIntl) {
      return;
    }

    this._intls = {
      ...this._intls,
      [resolvedLocale]: newIntl
    };
  }

  // willDestroy() {
  //   super.willDestroy();

  //   // eslint-disable-next-line ember/no-runloop
  //   cancel(this._timer);
  // }
}

// export { type Formats } from '../-private/formatjs/index';

declare module '@ember/service' {
  interface Registry {
    intl: IntlService;
  }
}

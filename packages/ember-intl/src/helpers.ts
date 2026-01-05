import { resource, resourceFactory } from 'ember-resources';

import type { FormatMessageParameters } from './formatters';

const formatDateTime = resourceFactory(
  (value: Date | number, options: Intl.DateTimeFormatOptions) =>
    resource(({ owner }) => {
      const intl = owner.lookup('service:intl');

      return intl.formatDateTime(value, options);
    })
);

const formatDuration = resourceFactory(
  (value: Intl.DurationInput, options: Intl.DurationFormatOptions) =>
    resource(({ owner }) => {
      const intl = owner.lookup('service:intl');

      return intl.formatDuration(value, options);
    })
);

const formatNumber = resourceFactory((value: number, options: Intl.NumberFormatOptions) =>
  resource(({ owner }) => {
    const intl = owner.lookup('service:intl');

    return intl.formatNumber(value, options);
  })
);

const formatRelativeTime = resourceFactory(
  (value: number, unit: Intl.RelativeTimeFormatUnit, options: Intl.RelativeTimeFormatOptions) =>
    resource(({ owner }) => {
      const intl = owner.lookup('service:intl');

      return intl.formatRelativeTime(value, unit, options);
    })
);

const t: (
  key: string,
  options?: FormatMessageParameters[1] & {
    htmlSafe?: boolean;
    locale?: string;
  }
) => string = resourceFactory(
  (
    key: string,
    options?: FormatMessageParameters[1] & {
      htmlSafe?: boolean;
      locale?: string;
    }
  ) =>
    resource(({ owner }) => {
      const intl = owner.lookup('service:intl');

      return intl.t(key, options);
    })
);

export { formatDateTime, formatDuration, formatNumber, formatRelativeTime, t };

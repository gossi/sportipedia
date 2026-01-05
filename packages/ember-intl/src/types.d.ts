declare module 'virtual:ember-intl-loader' {
  import type { Translations } from './utils/translations';

  const translations: Record<string, Translations>;

  export default translations;
}

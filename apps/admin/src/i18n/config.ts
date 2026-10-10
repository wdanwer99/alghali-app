export const locales = ['ar', 'en'] as const;
export type Locale = (typeof locales)[number];

/** Arabic first: anyone without a saved preference lands on Arabic. */
export const defaultLocale: Locale = 'ar';

/** Cookie the language switch writes so the proxy remembers the choice. */
export const LOCALE_COOKIE = 'NEXT_LOCALE';

export function isLocale(value: string | undefined): value is Locale {
  return value !== undefined && (locales as readonly string[]).includes(value);
}

export function dirOf(locale: Locale): 'rtl' | 'ltr' {
  return locale === 'ar' ? 'rtl' : 'ltr';
}

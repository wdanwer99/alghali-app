import type { Locale } from '@/i18n/config';

/** Fills `{name}` placeholders in a dictionary string. */
export function fill(template: string, values: Record<string, string | number>): string {
  return template.replace(/\{(\w+)\}/g, (_, key: string) => String(values[key] ?? `{${key}}`));
}

/**
 * Western digits in both languages, matching the apps and Bankak receipts
 * (D-048); dates and times in Africa/Khartoum.
 */
const intlLocale = (locale: Locale) => (locale === 'ar' ? 'ar-SD-u-nu-latn' : 'en-GB');

const grouped = new Intl.NumberFormat('en-US');

export function digits(n: number): string {
  return grouped.format(n);
}

/** Left-to-right isolate, so number ranges and references keep their order in Arabic. */
export function ltr(s: string): string {
  return `\u2066${s}\u2069`;
}

export function money(amount: number, template: string): string {
  return fill(template, { amount: digits(amount) });
}

/** "4815 1625". */
export function formatRef(ref: string): string {
  return ref.length === 8 ? ltr(`${ref.slice(0, 4)} ${ref.slice(4)}`) : ref;
}

export function dateTime(d: Date, locale: Locale): string {
  return new Intl.DateTimeFormat(intlLocale(locale), {
    timeZone: 'Africa/Khartoum',
    weekday: 'short',
    day: 'numeric',
    month: 'short',
    hour: 'numeric',
    minute: '2-digit',
  }).format(d);
}

export function shortDate(d: Date, locale: Locale): string {
  return new Intl.DateTimeFormat(intlLocale(locale), {
    timeZone: 'Africa/Khartoum',
    day: 'numeric',
    month: 'short',
  }).format(d);
}

/** "Sun 18 Oct". */
export function weekdayDate(d: Date, locale: Locale): string {
  return new Intl.DateTimeFormat(intlLocale(locale), {
    timeZone: 'Africa/Khartoum',
    weekday: 'short',
    day: 'numeric',
    month: 'short',
  }).format(d);
}

/** Lower-cases and folds Arabic letter variants so "احمد" finds "أحمد". */
export function searchKey(s: string): string {
  return s
    .toLowerCase()
    .replace(/[\u064B-\u0652\u0640]/g, '')
    .replace(/[أإآ]/g, 'ا')
    .replace(/ى/g, 'ي')
    .replace(/ة/g, 'ه')
    .replace(/\s+/g, ' ')
    .trim();
}

export function dayNumber(d: Date): string {
  return new Intl.DateTimeFormat('en-GB', { timeZone: 'Africa/Khartoum', day: 'numeric' }).format(
    d,
  );
}

/** "منذ 12 د" / "12 min ago", relative to [now]. */
export function ago(
  then: Date,
  now: Date,
  t: { agoMinutes: string; agoHours: string; agoDays: string },
): string {
  const minutes = Math.max(0, Math.round((now.getTime() - then.getTime()) / 60000));
  if (minutes < 60) return fill(t.agoMinutes, { n: minutes });
  const hours = Math.round(minutes / 60);
  if (hours < 24) return fill(t.agoHours, { n: hours });
  return fill(t.agoDays, { n: Math.round(hours / 24) });
}

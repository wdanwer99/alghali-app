// Words a notification from its template and payload, in the reader's language (D-091).
// {name} placeholders take payload values: keys ending in _at become a Khartoum weekday,
// day and time; keys ending in _sdg become money; unknown placeholders are dropped.
// Western digits in both languages (D-048).

const AR_DAYS = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
const EN_DAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const EN_MONTHS = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
const AR_MONTHS = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

export type Locale = 'ar' | 'en';

/** "12,000 ج.س" / "SDG 12,000" — as the apps show money. */
export function money(sdg: number, locale: Locale): string {
  const n = Math.round(sdg).toLocaleString('en-US');
  return locale === 'ar' ? `${n} ج.س` : `SDG ${n}`;
}

/** "الخميس 16 أكتوبر 4:00 م" / "Thu 16 Oct 4:00 PM", in Khartoum time (UTC+2). */
export function when(isoTime: string, locale: Locale): string {
  const t = new Date(Date.parse(isoTime) + 2 * 3_600_000);
  if (Number.isNaN(t.getTime())) return isoTime;
  const h = t.getUTCHours();
  const clock = `${h % 12 === 0 ? 12 : h % 12}:${String(t.getUTCMinutes()).padStart(2, '0')}`;
  const day = t.getUTCDate();
  return locale === 'ar'
    ? `${AR_DAYS[t.getUTCDay()]} ${day} ${AR_MONTHS[t.getUTCMonth()]} ${clock} ${h < 12 ? 'ص' : 'م'}`
    : `${EN_DAYS[t.getUTCDay()]} ${day} ${EN_MONTHS[t.getUTCMonth()]} ${clock} ${h < 12 ? 'AM' : 'PM'}`;
}

function value(key: string, v: unknown, locale: Locale): string {
  if (v === null || v === undefined) return '';
  if (key.endsWith('_at') || key === 'pay_by')
    return typeof v === 'string' ? when(v, locale) : String(v);
  if (key.endsWith('_sdg') && typeof v === 'number') return money(v, locale);
  if (typeof v === 'object') return '';
  return String(v);
}

export function render(template: string, payload: Record<string, unknown>, locale: Locale): string {
  return template
    .replace(/\{([a-z_]+)\}/g, (_, key: string) => value(key, payload[key], locale))
    .replace(/\s+([.،,:])/g, '$1')
    .replace(/\s{2,}/g, ' ')
    .trim();
}

/** FCM data values must be strings. */
export function dataOf(code: string, payload: Record<string, unknown>): Record<string, string> {
  const out: Record<string, string> = { code };
  for (const [k, v] of Object.entries(payload)) {
    if (v !== null && v !== undefined && typeof v !== 'object') out[k] = String(v);
  }
  return out;
}

/** Whether a failed send is worth retrying, from FCM's HTTP status and error status. */
export function retryable(httpStatus: number, fcmStatus?: string): boolean {
  if (
    fcmStatus === 'UNREGISTERED' ||
    fcmStatus === 'INVALID_ARGUMENT' ||
    fcmStatus === 'SENDER_ID_MISMATCH'
  ) {
    return false;
  }
  return httpStatus === 429 || httpStatus >= 500;
}

/**
 * Sample data for the screens whose tables arrive in M3 (bookings, disputes and
 * technician applications). Every screen that uses it says so with a "Sample data" banner.
 * Consistent with the phone apps' sample data. Amounts are illustrative SDG.
 */
import type { Locale } from '@/i18n/config';

export type L10n = { ar: string; en: string };
export const tr = (t: L10n, locale: Locale) => t[locale];

/** Fixed "now" so the demo renders the same on every request (and prerenders). */
export const DEMO_NOW = new Date('2026-10-14T07:30:00Z');
const minutesAgo = (m: number) => new Date(DEMO_NOW.getTime() - m * 60_000);

/** 8-digit order reference with a Luhn check digit (D-016). */
export function withCheckDigit(seven: string): string {
  let sum = 0;
  for (let i = 0; i < seven.length; i++) {
    let d = Number(seven[seven.length - 1 - i]);
    if (i % 2 === 0) {
      d *= 2;
      if (d > 9) d -= 9;
    }
    sum += d;
  }
  return `${seven}${(10 - (sum % 10)) % 10}`;
}

export const shops = {
  nour: { ar: 'النور لقطع الغيار', en: 'Al-Nour Auto Parts' },
  farouq: { ar: 'الفاروق لقطع تويوتا', en: 'Al-Farouq Toyota Parts' },
  tawfiq: { ar: 'التوفيق للفرامل والعفشة', en: 'Al-Tawfiq Brakes & Suspension' },
  baraka: { ar: 'البركة للبطاريات', en: 'Al-Baraka Batteries' },
  amin: { ar: 'الأمين للإسبيرات', en: 'Al-Amin Spares' },
  huda: { ar: 'الهدى لتكييف السيارات', en: 'Al-Huda Car AC' },
} satisfies Record<string, L10n>;

export const technicians = {
  osman: { ar: 'محمد عثمان', en: 'Mohamed Osman' },
  babiker: { ar: 'عمر بابكر', en: 'Omer Babiker' },
  tayeb: { ar: 'أحمد الطيب', en: 'Ahmed Eltayeb' },
  yasir: { ar: 'ياسر عبدالله', en: 'Yasir Abdalla' },
} satisfies Record<string, L10n>;

// -------------------------------------------------------------- applications --

export type Application = {
  id: string;
  kind: 'shop' | 'technician';
  name: L10n;
  submittedAt: Date;
  detail: L10n;
  docs: { key: 'license' | 'id' | 'photos' | 'certificate'; ok: boolean }[];
  mode?: 'bay' | 'mobile' | 'both';
  years?: number;
};

/** Technician applications (M3); shop applications are real (shops with status PENDING). */
export const applications: Application[] = [
  {
    id: 'app-3',
    kind: 'technician',
    name: { ar: 'عبدالرحيم موسى', en: 'Abdelrahim Musa' },
    submittedAt: minutesAgo(30 * 60),
    detail: { ar: 'تكييف وكهرباء', en: 'Air conditioning and electrical' },
    docs: [
      { key: 'id', ok: true },
      { key: 'certificate', ok: true },
    ],
    mode: 'mobile',
    years: 7,
  },
  {
    id: 'app-4',
    kind: 'technician',
    name: { ar: 'طارق حسن', en: 'Tarig Hassan' },
    submittedAt: minutesAgo(3 * 60),
    detail: { ar: 'فرامل — ورشة التوفيق', en: 'Brakes — Al-Tawfiq bay' },
    docs: [
      { key: 'id', ok: true },
      { key: 'certificate', ok: false },
    ],
    mode: 'bay',
    years: 4,
  },
];

// ------------------------------------------------------------------ bookings --

export type BookingStatus =
  | 'awaitingPayment'
  | 'pendingTechAccept'
  | 'accepted'
  | 'enRoute'
  | 'inProgress'
  | 'completed'
  | 'cancelledByBuyer';

export type BookingRow = {
  ref: string;
  startAt: Date;
  technician: L10n;
  buyer: string;
  place: 'bay' | 'customer';
  job: L10n;
  method: 'bankak' | 'cash';
  status: BookingStatus;
};

const at = (dayOffset: number, hour: number, minute = 0) =>
  new Date(Date.UTC(2026, 9, 14 + dayOffset, hour - 2, minute));

export const bookings: BookingRow[] = [
  {
    ref: withCheckDigit('5208113'),
    startAt: at(1, 10),
    technician: technicians.babiker,
    buyer: 'أحمد م.',
    place: 'bay',
    job: { ar: 'فحمات فرامل أمامية', en: 'Front brake pads' },
    method: 'bankak',
    status: 'accepted',
  },
  {
    ref: withCheckDigit('5208190'),
    startAt: at(0, 11, 30),
    technician: technicians.osman,
    buyer: 'هالة ع.',
    place: 'bay',
    job: { ar: 'بطارية 55 أمبير', en: '55 Ah battery' },
    method: 'bankak',
    status: 'accepted',
  },
  {
    ref: withCheckDigit('5208204'),
    startAt: at(0, 17),
    technician: technicians.osman,
    buyer: 'Sami K.',
    place: 'customer',
    job: { ar: 'فحص كهرباء', en: 'Electrical check' },
    method: 'cash',
    status: 'accepted',
  },
  {
    ref: withCheckDigit('5208231'),
    startAt: at(1, 16),
    technician: technicians.osman,
    buyer: 'أحمد م.',
    place: 'customer',
    job: { ar: 'لمبة هالوجين H4', en: 'H4 halogen bulb' },
    method: 'bankak',
    status: 'awaitingPayment',
  },
  {
    ref: withCheckDigit('5208255'),
    startAt: at(0, 9, 30),
    technician: technicians.tayeb,
    buyer: 'خالد س.',
    place: 'customer',
    job: { ar: 'كشافات ضباب LED', en: 'LED fog lamps' },
    method: 'bankak',
    status: 'inProgress',
  },
  {
    ref: withCheckDigit('5208270'),
    startAt: at(2, 10),
    technician: technicians.yasir,
    buyer: 'Huda K.',
    place: 'customer',
    job: { ar: 'تغيير زيت', en: 'Oil change' },
    method: 'cash',
    status: 'pendingTechAccept',
  },
  {
    ref: withCheckDigit('5207988'),
    startAt: at(-1, 18),
    technician: technicians.babiker,
    buyer: 'الطيب س.',
    place: 'bay',
    job: { ar: 'أقراص فرامل', en: 'Brake discs' },
    method: 'bankak',
    status: 'completed',
  },
  {
    ref: withCheckDigit('5207912'),
    startAt: at(-1, 12),
    technician: technicians.tayeb,
    buyer: 'Nada K.',
    place: 'customer',
    job: { ar: 'تعبئة غاز المكيف', en: 'AC gas refill' },
    method: 'cash',
    status: 'cancelledByBuyer',
  },
];

// ------------------------------------------------------------------ disputes --

export type DisputeRow = {
  id: string;
  type: 'wrongPart' | 'noShow' | 'refund' | 'damage';
  openedBy: string;
  related: string;
  openedAt: Date;
  status: 'open' | 'investigating' | 'resolved';
};

export const disputes: DisputeRow[] = [
  {
    id: 'dp-1',
    type: 'noShow',
    openedBy: 'Nada K.',
    related: withCheckDigit('5207912'),
    openedAt: minutesAgo(20 * 60),
    status: 'open',
  },
  {
    id: 'dp-2',
    type: 'wrongPart',
    openedBy: 'ياسر م.',
    related: withCheckDigit('6601790'),
    openedAt: minutesAgo(9 * 60),
    status: 'investigating',
  },
  {
    id: 'dp-3',
    type: 'refund',
    openedBy: 'Hassan Y.',
    related: withCheckDigit('6600954'),
    openedAt: minutesAgo(52 * 60),
    status: 'resolved',
  },
  {
    id: 'dp-4',
    type: 'damage',
    openedBy: 'عثمان ب.',
    related: withCheckDigit('6603551'),
    openedAt: minutesAgo(2 * 60),
    status: 'open',
  },
];

/**
 * Sample data for the screens whose tables don't exist yet (payments, orders,
 * cash and payouts arrive in M2; bookings, disputes and technician applications
 * in M3). Every screen that uses it says so with a "Sample data" banner.
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

// ------------------------------------------------------------------ payments --

export type ReceiptReview = {
  id: string;
  ref: string;
  buyer: string;
  dueSdg: number;
  transferredSdg: number;
  txn: string;
  refInNote: boolean;
  txnUsedBefore: boolean;
  submittedAt: Date;
  shops: L10n[];
  hasFitting: boolean;
};

export const receipts: ReceiptReview[] = [
  {
    id: 'pay-1',
    ref: withCheckDigit('6604302'),
    buyer: 'منى ح.',
    dueSdg: 90000,
    transferredSdg: 90000,
    txn: '200991873',
    refInNote: true,
    txnUsedBefore: false,
    submittedAt: minutesAgo(42),
    shops: [shops.nour],
    hasFitting: false,
  },
  {
    id: 'pay-2',
    ref: withCheckDigit('6604355'),
    buyer: 'أحمد م.',
    dueSdg: 23000,
    transferredSdg: 23000,
    txn: '200992014',
    refInNote: true,
    txnUsedBefore: false,
    submittedAt: minutesAgo(18),
    shops: [shops.nour],
    hasFitting: true,
  },
  {
    id: 'pay-3',
    ref: withCheckDigit('6604390'),
    buyer: 'Sara A.',
    dueSdg: 38000,
    transferredSdg: 33000,
    txn: '200992101',
    refInNote: true,
    txnUsedBefore: false,
    submittedAt: minutesAgo(9),
    shops: [shops.tawfiq],
    hasFitting: false,
  },
  {
    id: 'pay-4',
    ref: withCheckDigit('6604412'),
    buyer: 'عمر ط.',
    dueSdg: 145000,
    transferredSdg: 145000,
    txn: '200987361',
    refInNote: false,
    txnUsedBefore: true,
    submittedAt: minutesAgo(4),
    shops: [shops.baraka, shops.amin],
    hasFitting: false,
  },
];

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

// -------------------------------------------------------------------- orders --

export type OrderStatus =
  | 'pendingPayment'
  | 'paymentReview'
  | 'confirmed'
  | 'ready'
  | 'pickedUp'
  | 'handedToTechnician'
  | 'completed'
  | 'cancelled';
export type PaymentStatus =
  'awaitingTransfer' | 'receiptSubmitted' | 'confirmed' | 'due' | 'collected' | 'expired';

export type OrderRow = {
  ref: string;
  placedAt: Date;
  buyer: string;
  shops: number;
  items: number;
  totalSdg: number;
  method: 'bankak' | 'cash';
  payment: PaymentStatus;
  status: OrderStatus;
};

export const orders: OrderRow[] = [
  {
    ref: withCheckDigit('6604412'),
    placedAt: minutesAgo(31),
    buyer: 'عمر ط.',
    shops: 2,
    items: 2,
    totalSdg: 145000,
    method: 'bankak',
    payment: 'receiptSubmitted',
    status: 'paymentReview',
  },
  {
    ref: withCheckDigit('6604390'),
    placedAt: minutesAgo(40),
    buyer: 'Sara A.',
    shops: 1,
    items: 1,
    totalSdg: 38000,
    method: 'bankak',
    payment: 'receiptSubmitted',
    status: 'paymentReview',
  },
  {
    ref: withCheckDigit('6604355'),
    placedAt: minutesAgo(55),
    buyer: 'أحمد م.',
    shops: 1,
    items: 1,
    totalSdg: 23000,
    method: 'bankak',
    payment: 'receiptSubmitted',
    status: 'paymentReview',
  },
  {
    ref: withCheckDigit('6604302'),
    placedAt: minutesAgo(70),
    buyer: 'منى ح.',
    shops: 1,
    items: 2,
    totalSdg: 90000,
    method: 'bankak',
    payment: 'receiptSubmitted',
    status: 'paymentReview',
  },
  {
    ref: withCheckDigit('6604217'),
    placedAt: minutesAgo(95),
    buyer: 'هبة ي.',
    shops: 1,
    items: 1,
    totalSdg: 12000,
    method: 'bankak',
    payment: 'confirmed',
    status: 'confirmed',
  },
  {
    ref: withCheckDigit('6603985'),
    placedAt: minutesAgo(130),
    buyer: 'سارة ع.',
    shops: 1,
    items: 1,
    totalSdg: 45000,
    method: 'cash',
    payment: 'due',
    status: 'confirmed',
  },
  {
    ref: withCheckDigit('6603551'),
    placedAt: minutesAgo(180),
    buyer: 'عثمان ب.',
    shops: 1,
    items: 1,
    totalSdg: 195000,
    method: 'bankak',
    payment: 'confirmed',
    status: 'ready',
  },
  {
    ref: withCheckDigit('6603402'),
    placedAt: minutesAgo(240),
    buyer: 'Tariq A.',
    shops: 1,
    items: 3,
    totalSdg: 61500,
    method: 'bankak',
    payment: 'awaitingTransfer',
    status: 'pendingPayment',
  },
  {
    ref: withCheckDigit('6602877'),
    placedAt: minutesAgo(320),
    buyer: 'خالد س.',
    shops: 1,
    items: 1,
    totalSdg: 72000,
    method: 'bankak',
    payment: 'confirmed',
    status: 'handedToTechnician',
  },
  {
    ref: withCheckDigit('6601790'),
    placedAt: minutesAgo(1560),
    buyer: 'ياسر م.',
    shops: 1,
    items: 2,
    totalSdg: 12000,
    method: 'bankak',
    payment: 'confirmed',
    status: 'completed',
  },
  {
    ref: withCheckDigit('6601422'),
    placedAt: minutesAgo(2700),
    buyer: 'Nada K.',
    shops: 1,
    items: 1,
    totalSdg: 145000,
    method: 'bankak',
    payment: 'confirmed',
    status: 'completed',
  },
  {
    ref: withCheckDigit('6601108'),
    placedAt: minutesAgo(3000),
    buyer: 'ريم أ.',
    shops: 1,
    items: 1,
    totalSdg: 45000,
    method: 'cash',
    payment: 'collected',
    status: 'completed',
  },
  {
    ref: withCheckDigit('6600954'),
    placedAt: minutesAgo(3300),
    buyer: 'Hassan Y.',
    shops: 1,
    items: 1,
    totalSdg: 9500,
    method: 'bankak',
    payment: 'expired',
    status: 'cancelled',
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

// ---------------------------------------------------------------------- cash --

export type CashRow = {
  partner: L10n;
  role: 'shop' | 'technician';
  collectedSdg: number;
  handedSdg: number;
  owedSdg: number;
  cycles: number;
};

export const cashRows: CashRow[] = [
  {
    partner: technicians.osman,
    role: 'technician',
    collectedSdg: 18000,
    handedSdg: 0,
    owedSdg: 2000,
    cycles: 0,
  },
  {
    partner: technicians.yasir,
    role: 'technician',
    collectedSdg: 41000,
    handedSdg: 14000,
    owedSdg: 6000,
    cycles: 1,
  },
  {
    partner: shops.nour,
    role: 'shop',
    collectedSdg: 45000,
    handedSdg: 0,
    owedSdg: 2250,
    cycles: 0,
  },
  {
    partner: shops.amin,
    role: 'shop',
    collectedSdg: 128000,
    handedSdg: 0,
    owedSdg: 6400,
    cycles: 2,
  },
  {
    partner: technicians.tayeb,
    role: 'technician',
    collectedSdg: 27000,
    handedSdg: 12000,
    owedSdg: 4000,
    cycles: 0,
  },
  {
    partner: shops.tawfiq,
    role: 'shop',
    collectedSdg: 76000,
    handedSdg: 0,
    owedSdg: 3800,
    cycles: 1,
  },
];

// ------------------------------------------------------------------- payouts --

export type PayoutRow = {
  id: string;
  partner: L10n;
  role: 'shop' | 'technician';
  grossSdg: number;
  deductionsSdg: number;
  status: 'draft' | 'approved' | 'paid';
};

/** This week (Sun–Sat, Khartoum) and the Sunday the payouts go out. */
export const payoutWeek = {
  from: new Date(Date.UTC(2026, 9, 11, 10)),
  to: new Date(Date.UTC(2026, 9, 17, 10)),
  payDay: new Date(Date.UTC(2026, 9, 18, 10)),
};

/** Bankak transaction numbers already recorded for paid payouts. */
export const payoutTxns: Record<string, string> = { 'po-7': '200990127' };

export const payouts: PayoutRow[] = [
  {
    id: 'po-1',
    partner: shops.nour,
    role: 'shop',
    grossSdg: 202000,
    deductionsSdg: 10100,
    status: 'draft',
  },
  {
    id: 'po-2',
    partner: shops.farouq,
    role: 'shop',
    grossSdg: 486500,
    deductionsSdg: 24325,
    status: 'draft',
  },
  {
    id: 'po-3',
    partner: shops.tawfiq,
    role: 'shop',
    grossSdg: 233000,
    deductionsSdg: 11650,
    status: 'approved',
  },
  {
    id: 'po-4',
    partner: shops.baraka,
    role: 'shop',
    grossSdg: 325000,
    deductionsSdg: 16250,
    status: 'draft',
  },
  {
    id: 'po-5',
    partner: technicians.osman,
    role: 'technician',
    grossSdg: 54000,
    deductionsSdg: 4000,
    status: 'draft',
  },
  {
    id: 'po-6',
    partner: technicians.babiker,
    role: 'technician',
    grossSdg: 75000,
    deductionsSdg: 10000,
    status: 'approved',
  },
  {
    id: 'po-7',
    partner: technicians.tayeb,
    role: 'technician',
    grossSdg: 41000,
    deductionsSdg: 6000,
    status: 'paid',
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

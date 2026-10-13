// Turns the cells of a shop's stock sheet into rows for the shop_import_rows RPC.
// Pure TypeScript (no Deno or Node APIs) so vitest covers it and the Edge Function reuses it.
//
// The sheet needs a header row (anywhere in the first 10 rows) with at least a name column.
// Headers may be Arabic or English and are matched loosely ("السعر (جنيه)" is the price).
// The database decides what the values mean (category, models, duplicates); this file only
// reads them: digits in any script, prices with separators and currency words, warranties
// like "6 أشهر", and the common words shops use for a part's condition.

export type Condition = 'NEW_OEM' | 'NEW_AFTERMARKET' | 'USED';

export interface ImportRow {
  row: number; // 1-based row number as the shop sees it in Excel
  sku?: string;
  name_ar: string;
  name_en?: string;
  category: string;
  condition: Condition;
  price_sdg: number | null;
  price_on_request: boolean;
  stock_qty: number;
  warranty_days: number;
  brand?: string;
  models?: string[];
  oem?: string;
}

export type IssueCode =
  | 'HEADER_NOT_FOUND'
  | 'TOO_MANY_ROWS'
  | 'CATEGORY_REQUIRED'
  | 'CONDITION_REQUIRED'
  | 'INVALID_CONDITION'
  | 'INVALID_PRICE'
  | 'INVALID_QTY'
  | 'INVALID_WARRANTY'
  | 'NAME_REQUIRED';

export interface SheetIssue {
  row: number;
  code: IssueCode;
  column?: Column;
}

export type Column =
  | 'sku'
  | 'name_ar'
  | 'name_en'
  | 'category'
  | 'condition'
  | 'price'
  | 'qty'
  | 'warranty'
  | 'brand'
  | 'models'
  | 'oem';

export const MAX_ROWS = 2000;

/** Column titles of the downloadable template (infra/scripts/make-import-template.mjs). */
export const TEMPLATE_HEADERS = [
  'رمز الصنف (اختياري)',
  'اسم القطعة',
  'الفئة',
  'الحالة',
  'السعر (جنيه)',
  'الكمية',
  'الضمان',
  'الماركة',
  'السيارات',
  'رقم القطعة (OEM)',
] as const;

/** Header words per column, already in normalised form (see `key`). Order matters: first match wins. */
const HEADERS: [Column, string[]][] = [
  ['sku', ['sku', 'code', 'رمزالصنف', 'رمز', 'الكود', 'كود']],
  ['oem', ['oem', 'partnumber', 'partno', 'رقمالقطعه', 'الرقمالاصلي']],
  ['name_en', ['nameen', 'englishname', 'الاسمبالانجليزي', 'الاسمالانجليزي']],
  [
    'name_ar',
    [
      'namear',
      'name',
      'partname',
      'part',
      'item',
      'اسمالقطعه',
      'اسمالصنف',
      'القطعه',
      'الصنف',
      'الاسم',
    ],
  ],
  ['category', ['category', 'الفئه', 'القسم', 'التصنيف', 'النوع']],
  ['condition', ['condition', 'الحاله']],
  ['price', ['price', 'السعر', 'سعر']],
  ['qty', ['qty', 'quantity', 'stock', 'الكميه', 'كميه', 'العدد', 'المخزون']],
  ['warranty', ['warranty', 'الضمان', 'ضمان']],
  ['brand', ['brand', 'make', 'الماركه', 'ماركه', 'الشركه']],
  ['models', ['models', 'cars', 'fits', 'السيارات', 'الموديلات', 'الموديل', 'يناسب', 'العربات']],
];

const CONDITIONS: [Condition, string[]][] = [
  ['NEW_OEM', ['newoem', 'oem', 'original', 'genuine', 'جديداصلي', 'اصلي', 'وكاله', 'جديدوكاله']],
  [
    'NEW_AFTERMARKET',
    [
      'newaftermarket',
      'aftermarket',
      'new',
      'جديد',
      'تجاري',
      'جديدتجاري',
      'كوري',
      'صيني',
      'تايواني',
      'بديل',
    ],
  ],
  ['USED', ['used', 'مستعمل', 'مستخدم', 'تشليح', 'قديم']],
];

/** Same rules as the database's ar_normalize, plus Arabic-Indic digits. */
export function normalize(input: string): string {
  let out = '';
  for (const ch of input) {
    const c = ch.codePointAt(0)!;
    if ((c >= 0x064b && c <= 0x0652) || c === 0x0670 || c === 0x0640) continue;
    if (c >= 0x0660 && c <= 0x0669) out += String(c - 0x0660);
    else if (c >= 0x06f0 && c <= 0x06f9) out += String(c - 0x06f0);
    else if (c === 0x0623 || c === 0x0625 || c === 0x0622 || c === 0x0671) out += 'ا';
    else if (c === 0x0629) out += 'ه';
    else if (c === 0x0649 || c === 0x06cc) out += 'ي';
    else if (c === 0x06a9) out += 'ك';
    else out += ch;
  }
  return out.toLowerCase().replace(/\s+/g, ' ').trim();
}

/** Normalised with everything but letters and digits removed, for matching labels. */
const key = (s: string) => normalize(s).replace(/[^\p{L}\p{N}]/gu, '');

function text(cell: unknown): string {
  if (cell === null || cell === undefined) return '';
  return String(cell).trim();
}

function findColumns(
  cells: unknown[][],
): { headerIndex: number; columns: Map<Column, number> } | null {
  for (let r = 0; r < Math.min(cells.length, 10); r++) {
    const row = cells[r] ?? [];
    const columns = new Map<Column, number>();
    row.forEach((cell, c) => {
      const k = key(text(cell));
      if (!k) return;
      const exact = HEADERS.find(([col, words]) => !columns.has(col) && words.includes(k));
      const loose =
        exact ??
        HEADERS.find(([col, words]) => !columns.has(col) && words.some((w) => k.startsWith(w)));
      if (loose) columns.set(loose[0], c);
    });
    if (columns.has('name_ar')) return { headerIndex: r, columns };
  }
  return null;
}

/** "45,000", "٤٥٠٠٠ ج", "45000 SDG", 45000 → 45000. Null when empty; NaN when unreadable. */
export function parseMoney(cell: unknown): number | null {
  if (typeof cell === 'number') return Number.isInteger(cell) && cell >= 0 ? cell : Number.NaN;
  const s = normalize(text(cell))
    .replace(/sdg|جنيه|ج\.?س|ج/g, '')
    .replace(/[,\s٬،]/g, '');
  if (s === '') return null;
  if (!/^\d+(\.0+)?$/.test(s)) return Number.NaN;
  return Number.parseInt(s, 10);
}

/** Days of warranty: 90, "90 يوم", "6 أشهر", "سنة", "سنتين", "بدون" → 90, 90, 180, 365, 730, 0. */
export function parseWarranty(cell: unknown): number | null {
  if (typeof cell === 'number') return Number.isInteger(cell) && cell >= 0 ? cell : Number.NaN;
  const s = normalize(text(cell));
  if (s === '') return 0;
  if (/^(بدون|لا|لايوجد|لا يوجد|none|no|0)$/.test(s)) return 0;
  if (/^سنتين$/.test(s)) return 730;
  if (/^شهرين$/.test(s)) return 60;
  const m =
    /^(\d+)?\s*(يوم|ايام|days?|d|اسبوع|اسابيع|weeks?|w|شهر|اشهر|شهور|months?|m|سنه|سنوات|سنين|years?|y)?$/.exec(
      s,
    );
  if (!m || (!m[1] && !m[2])) return Number.NaN;
  const n = m[1] ? Number.parseInt(m[1], 10) : 1;
  const unit = m[2] ?? 'يوم';
  if (/^(اسبوع|اسابيع|weeks?|w)$/.test(unit)) return n * 7;
  if (/^(شهر|اشهر|شهور|months?|m)$/.test(unit)) return n * 30;
  if (/^(سنه|سنوات|سنين|years?|y)$/.test(unit)) return n * 365;
  return n;
}

export function parseCondition(cell: unknown): Condition | null | undefined {
  const raw = text(cell);
  if (raw === '') return null;
  if (raw === 'NEW_OEM' || raw === 'NEW_AFTERMARKET' || raw === 'USED') return raw;
  const k = key(raw);
  for (const [condition, words] of CONDITIONS) if (words.includes(k)) return condition;
  return undefined;
}

export function parseModels(cell: unknown): string[] {
  return text(cell)
    .split(/[,،/\n;]| و /)
    .map((s) => s.trim())
    .filter(Boolean);
}

const ON_REQUEST = /^(عندالطلب|حسبالطلب|اتصل|onrequest|ask|call)$/;

export interface ParsedSheet {
  rows: ImportRow[];
  issues: SheetIssue[];
}

export function parseSheet(cells: unknown[][]): ParsedSheet {
  const found = findColumns(cells);
  if (!found) return { rows: [], issues: [{ row: 0, code: 'HEADER_NOT_FOUND' }] };
  const { headerIndex, columns } = found;
  const get = (row: unknown[], col: Column) =>
    columns.has(col) ? row[columns.get(col)!] : undefined;

  const rows: ImportRow[] = [];
  const issues: SheetIssue[] = [];
  let dataRows = 0;
  for (let r = headerIndex + 1; r < cells.length; r++) {
    const cellsOfRow = cells[r] ?? [];
    if (cellsOfRow.every((c) => text(c) === '')) continue;
    if (++dataRows > MAX_ROWS) return { rows: [], issues: [{ row: 0, code: 'TOO_MANY_ROWS' }] };
    const rowNo = r + 1;
    const issue = (code: IssueCode, column?: Column) => issues.push({ row: rowNo, code, column });

    const name = text(get(cellsOfRow, 'name_ar'));
    if (!name) {
      issue('NAME_REQUIRED', 'name_ar');
      continue;
    }
    const category = text(get(cellsOfRow, 'category'));
    if (!category) {
      issue('CATEGORY_REQUIRED', 'category');
      continue;
    }
    const condition = parseCondition(get(cellsOfRow, 'condition'));
    if (condition === null) {
      issue('CONDITION_REQUIRED', 'condition');
      continue;
    }
    if (condition === undefined) {
      issue('INVALID_CONDITION', 'condition');
      continue;
    }
    const priceCell = get(cellsOfRow, 'price');
    const onRequest = ON_REQUEST.test(key(text(priceCell)));
    const price = onRequest ? null : parseMoney(priceCell);
    if (Number.isNaN(price)) {
      issue('INVALID_PRICE', 'price');
      continue;
    }
    const qty = parseMoney(get(cellsOfRow, 'qty'));
    if (qty === null || Number.isNaN(qty)) {
      issue('INVALID_QTY', 'qty');
      continue;
    }
    const warranty = parseWarranty(get(cellsOfRow, 'warranty'));
    if (warranty === null || Number.isNaN(warranty)) {
      issue('INVALID_WARRANTY', 'warranty');
      continue;
    }

    const optional = (col: Column) => text(get(cellsOfRow, col)) || undefined;
    const models = parseModels(get(cellsOfRow, 'models'));
    rows.push({
      row: rowNo,
      sku: optional('sku'),
      name_ar: name,
      name_en: optional('name_en'),
      category,
      condition,
      price_sdg: price,
      price_on_request: onRequest,
      stock_qty: qty,
      warranty_days: warranty,
      brand: optional('brand'),
      models: models.length ? models : undefined,
      oem: optional('oem'),
    });
  }
  return { rows, issues };
}

/** The import report the app shows: database results plus rows the sheet reader skipped. */
export interface ImportReport {
  total: number;
  created: number;
  updated: number;
  failed: number;
  dry_run: boolean;
  job_id?: string;
  errors: { row: number; code: string; column?: string }[];
  warnings: { row: number; code: string; value?: string }[];
}

export function mergeReport(db: ImportReport, sheet: SheetIssue[]): ImportReport {
  const errors = [
    ...sheet.map(({ row, code, column }) => ({ row, code, column })),
    ...db.errors,
  ].sort((a, b) => a.row - b.row);
  return { ...db, total: db.total + sheet.length, failed: db.failed + sheet.length, errors };
}

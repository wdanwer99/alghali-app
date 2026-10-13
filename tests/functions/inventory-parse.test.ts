import { describe, expect, it } from 'vitest';
import * as XLSX from '../../supabase/functions/_shared/vendor/sheetjs/xlsx.mjs';
import { must } from '../support/must.ts';
import {
  mergeReport,
  parseCondition,
  parseModels,
  parseMoney,
  parseSheet,
  parseWarranty,
  TEMPLATE_HEADERS,
} from '../../supabase/functions/_shared/inventory/parse.ts';

/** Round-trips cells through a real .xlsx file, the way the Edge Function reads uploads. */
function throughXlsx(cells: unknown[][]): unknown[][] {
  const book = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(book, XLSX.utils.aoa_to_sheet(cells), 'المخزون');
  const bytes = XLSX.write(book, { type: 'array', bookType: 'xlsx' }) as ArrayBuffer;
  const back = XLSX.read(new Uint8Array(bytes), { type: 'array', dense: true });
  return XLSX.utils.sheet_to_json(must(back.Sheets[must(back.SheetNames[0])]), {
    header: 1,
    raw: true,
    defval: null,
    blankrows: true,
  });
}

describe('stock sheet values', () => {
  it.each([
    [45000, 45000],
    ['45,000', 45000],
    ['٤٥٠٠٠', 45000],
    ['45000 ج', 45000],
    ['45000 جنيه', 45000],
    ['45000 SDG', 45000],
    ['45000.00', 45000],
    ['', null],
    [null, null],
    ['45.5', Number.NaN],
    [45000.5, Number.NaN],
    [-5, Number.NaN],
    ['غالي', Number.NaN],
  ])('price %j → %s', (input, expected) => {
    expect(parseMoney(input)).toBe(expected);
  });

  it.each([
    [90, 90],
    ['90', 90],
    ['٩٠ يوم', 90],
    ['30 أيام', 30],
    ['6 أشهر', 180],
    ['شهر', 30],
    ['شهرين', 60],
    ['سنة', 365],
    ['سنتين', 730],
    ['2 سنوات', 730],
    ['أسبوع', 7],
    ['1 year', 365],
    ['بدون', 0],
    ['لا يوجد', 0],
    ['', 0],
    ['طويل', Number.NaN],
  ])('warranty %j → %s days', (input, expected) => {
    expect(parseWarranty(input)).toBe(expected);
  });

  it.each([
    ['جديد أصلي', 'NEW_OEM'],
    ['أصلي', 'NEW_OEM'],
    ['وكالة', 'NEW_OEM'],
    ['جديد', 'NEW_AFTERMARKET'],
    ['تجاري', 'NEW_AFTERMARKET'],
    ['Aftermarket', 'NEW_AFTERMARKET'],
    ['مستعمل', 'USED'],
    ['تشليح', 'USED'],
    ['USED', 'USED'],
    ['', null],
    ['ممتاز', undefined],
  ])('condition %j → %s', (input, expected) => {
    expect(parseCondition(input)).toBe(expected);
  });

  it('splits the car list on commas, Arabic commas, slashes and "و"', () => {
    expect(parseModels('هايلكس، كورولا/ صني و باترول\nL200')).toEqual([
      'هايلكس',
      'كورولا',
      'صني',
      'باترول',
      'L200',
    ]);
    expect(parseModels(null)).toEqual([]);
  });
});

describe('parseSheet', () => {
  it('reads the template’s Arabic headers and every column', () => {
    const cells = throughXlsx([
      [...TEMPLATE_HEADERS],
      [
        'P-1',
        'فحمات أمامية',
        'الفرامل',
        'أصلي',
        '65,000',
        10,
        '6 أشهر',
        'Toyota',
        'هايلكس، برادو',
        '04465-0K290',
      ],
      [1002, 'زيت 5W-30', 'الزيوت والفلاتر', 'جديد', 42000, '٦٠', '', '', '', ''],
      ['', 'مكينة', 'المحرك والتبريد', 'مستعمل', 'عند الطلب', 1, 'بدون', '', '', ''],
    ]);
    const { rows, issues } = parseSheet(cells);
    expect(issues).toEqual([]);
    expect(rows).toEqual([
      {
        row: 2,
        sku: 'P-1',
        name_ar: 'فحمات أمامية',
        name_en: undefined,
        category: 'الفرامل',
        condition: 'NEW_OEM',
        price_sdg: 65000,
        price_on_request: false,
        stock_qty: 10,
        warranty_days: 180,
        brand: 'Toyota',
        models: ['هايلكس', 'برادو'],
        oem: '04465-0K290',
      },
      expect.objectContaining({
        row: 3,
        sku: '1002',
        price_sdg: 42000,
        stock_qty: 60,
        warranty_days: 0,
        models: undefined,
      }),
      expect.objectContaining({
        row: 4,
        sku: undefined,
        condition: 'USED',
        price_sdg: null,
        price_on_request: true,
      }),
    ]);
  });

  it('finds a header below a title, in English, and skips blank rows', () => {
    const cells = throughXlsx([
      ['Stock list — Al-Nour'],
      [],
      ['Name', 'Category', 'Condition', 'Price', 'Qty', 'Name (English)'],
      ['لمبة H4', 'lighting', 'new', 12000, 40, 'H4 bulb'],
      [],
      ['لمبة H7', 'lighting', 'new', 13000, 20, ''],
    ]);
    const { rows, issues } = parseSheet(cells);
    expect(issues).toEqual([]);
    expect(rows.map((r) => [r.row, r.name_ar, r.name_en])).toEqual([
      [4, 'لمبة H4', 'H4 bulb'],
      [6, 'لمبة H7', undefined],
    ]);
  });

  it('reports rows it cannot read, with the row number and column', () => {
    const cells = throughXlsx([
      ['اسم القطعة', 'الفئة', 'الحالة', 'السعر', 'الكمية', 'الضمان'],
      ['', 'الفرامل', 'جديد', 1000, 1, ''],
      ['فحمات', '', 'جديد', 1000, 1, ''],
      ['فحمات', 'الفرامل', '', 1000, 1, ''],
      ['فحمات', 'الفرامل', 'ممتاز', 1000, 1, ''],
      ['فحمات', 'الفرامل', 'جديد', 'غالي', 1, ''],
      ['فحمات', 'الفرامل', 'جديد', 1000, '', ''],
      ['فحمات', 'الفرامل', 'جديد', 1000, 1, 'طويل'],
      ['فحمات', 'الفرامل', 'جديد', 1000, 1, 'سنة'],
    ]);
    const { rows, issues } = parseSheet(cells);
    expect(issues).toEqual([
      { row: 2, code: 'NAME_REQUIRED', column: 'name_ar' },
      { row: 3, code: 'CATEGORY_REQUIRED', column: 'category' },
      { row: 4, code: 'CONDITION_REQUIRED', column: 'condition' },
      { row: 5, code: 'INVALID_CONDITION', column: 'condition' },
      { row: 6, code: 'INVALID_PRICE', column: 'price' },
      { row: 7, code: 'INVALID_QTY', column: 'qty' },
      { row: 8, code: 'INVALID_WARRANTY', column: 'warranty' },
    ]);
    expect(rows.map((r) => r.row)).toEqual([9]);
  });

  it('needs a name column, and refuses huge sheets', () => {
    expect(
      parseSheet([
        ['foo', 'bar'],
        [1, 2],
      ]).issues,
    ).toEqual([{ row: 0, code: 'HEADER_NOT_FOUND' }]);
    const big = [
      ['name', 'category', 'condition', 'price', 'qty'],
      ...Array.from({ length: 2001 }, () => ['x', 'c', 'new', 1, 1]),
    ];
    expect(parseSheet(big).issues).toEqual([{ row: 0, code: 'TOO_MANY_ROWS' }]);
  });

  it('merges sheet issues into the database report', () => {
    const merged = mergeReport(
      {
        total: 2,
        created: 1,
        updated: 0,
        failed: 1,
        dry_run: false,
        errors: [{ row: 5, code: 'CATEGORY_NOT_FOUND' }],
        warnings: [],
      },
      [{ row: 3, code: 'INVALID_PRICE', column: 'price' }],
    );
    expect(merged).toMatchObject({ total: 3, failed: 2 });
    expect(merged.errors.map((e) => e.row)).toEqual([3, 5]);
  });
});

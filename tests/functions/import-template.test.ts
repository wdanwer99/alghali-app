import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import * as XLSX from '../../supabase/functions/_shared/vendor/sheetjs/xlsx.mjs';
import { parseSheet, TEMPLATE_HEADERS } from '../../supabase/functions/_shared/inventory/parse.ts';
import { must } from '../support/must.ts';

const root = join(import.meta.dirname, '../..');
const book = XLSX.read(readFileSync(join(root, 'supabase/templates/inventory-template.xlsx')), {
  type: 'buffer',
});
const rowsOf = (name: string) =>
  XLSX.utils.sheet_to_json<unknown[]>(must(book.Sheets[name], name), {
    header: 1,
    raw: true,
    defval: null,
  });

describe('the downloadable import template', () => {
  it('starts with the stock sheet, right-to-left, holding only the header row', () => {
    expect(book.SheetNames).toEqual(['المخزون', 'تعليمات']);
    expect(book.Workbook?.Views?.[0]?.RTL).toBe(true);
    expect(rowsOf('المخزون')).toEqual([[...TEMPLATE_HEADERS]]);
  });

  it('has headers the importer understands, column by column', () => {
    const [header] = rowsOf('المخزون');
    const sample = [
      'S-1',
      'فحمات',
      'الفرامل',
      'أصلي',
      100,
      2,
      'سنة',
      'Bosch',
      'هايلكس',
      '04465-0K290',
    ];
    const { rows, issues } = parseSheet([must(header), sample]);
    expect(issues).toEqual([]);
    expect(rows[0]).toEqual({
      row: 2,
      sku: 'S-1',
      name_ar: 'فحمات',
      name_en: undefined,
      category: 'الفرامل',
      condition: 'NEW_OEM',
      price_sdg: 100,
      price_on_request: false,
      stock_qty: 2,
      warranty_days: 365,
      brand: 'Bosch',
      models: ['هايلكس'],
      oem: '04465-0K290',
    });
  });

  it('lists exactly the starter categories, so shops copy names that match', () => {
    const help = rowsOf('تعليمات').map((r) => r[0]);
    const start = help.indexOf('الفئات') + 1;
    const listed = help.slice(start, help.indexOf(null, start));
    const sql = readFileSync(
      join(root, 'supabase/migrations/20261013100600_starter_catalogue.sql'),
      'utf8',
    );
    const seeded = [...sql.matchAll(/^\s+\('[a-z-]+',\s+'([^']+)',/gm)]
      .map((m) => m[1])
      .slice(0, 12);
    expect(listed).toEqual(seeded);
  });

  it('its example rows import cleanly', () => {
    const help = rowsOf('تعليمات');
    const at = help.findIndex((r) => r[0] === TEMPLATE_HEADERS[0]);
    const { rows, issues } = parseSheet(help.slice(at));
    expect(issues).toEqual([]);
    expect(rows).toHaveLength(3);
  });
});

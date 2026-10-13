// Writes supabase/templates/inventory-template.xlsx, the sheet shops download to import stock.
//   node infra/scripts/make-import-template.mjs
// The header titles must stay readable by supabase/functions/_shared/inventory/parse.ts —
// tests/functions/import-template.test.ts checks the committed file against the parser.
import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import * as XLSX from '../../supabase/functions/_shared/vendor/sheetjs/xlsx.mjs';
import { root } from './lib/paths.mjs';

const HEADERS = [
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
];

const CATEGORIES = [
  'الإضاءة',
  'الفرامل',
  'الزيوت والفلاتر',
  'البطاريات',
  'الكهرباء',
  'التكييف',
  'العفشة والتوجيه',
  'الإطارات والجنوط',
  'المحرك والتبريد',
  'القير والكلتش',
  'البودي والزجاج',
  'الإكسسوارات',
];

const instructions = [
  ['كيف تملأ ملف المخزون'],
  [],
  ['اكتب كل قطعة في سطر واحد في ورقة "المخزون". لا تغيّر عناوين الأعمدة.'],
  [
    'يمكنك رفع الملف أكثر من مرة: السطر الذي له نفس "رمز الصنف" يحدّث السعر والكمية بدل أن يضيف قطعة جديدة.',
  ],
  [],
  ['العمود', 'مطلوب؟', 'ماذا تكتب'],
  ['رمز الصنف', 'لا', 'رمزك الخاص للقطعة. يساعد على تحديث نفس القطعة لاحقاً.'],
  ['اسم القطعة', 'نعم', 'مثل: فحمات فرامل أمامية'],
  ['الفئة', 'نعم', 'واحدة من الفئات في الأسفل'],
  ['الحالة', 'نعم', 'أصلي، أو جديد (تجاري)، أو مستعمل'],
  ['السعر (جنيه)', 'نعم', 'رقم فقط، مثل 45000. أو اكتب "عند الطلب"'],
  ['الكمية', 'نعم', 'عدد القطع الموجودة عندك'],
  ['الضمان', 'لا', 'مثل: 30 يوم، 6 أشهر، سنة، بدون'],
  ['الماركة', 'لا', 'مثل: Toyota، Bosch، Denso'],
  ['السيارات', 'لا', 'الموديلات التي تناسبها القطعة، بينها فاصلة: هايلكس، برادو'],
  ['رقم القطعة (OEM)', 'لا', 'الرقم الأصلي المكتوب على القطعة'],
  [],
  ['الفئات'],
  ...CATEGORIES.map((c) => [c]),
  [],
  ['أمثلة'],
  HEADERS,
  [
    'BR-101',
    'فحمات فرامل أمامية',
    'الفرامل',
    'أصلي',
    65000,
    10,
    '6 أشهر',
    'Toyota',
    'هايلكس',
    '04465-0K290',
  ],
  ['', 'زيت محرك 5W-30', 'الزيوت والفلاتر', 'جديد', 42000, 60, '', 'Shell', '', ''],
  ['', 'كمبروسر مكيف', 'التكييف', 'مستعمل', 'عند الطلب', 1, '30 يوم', '', 'هايلكس، برادو', ''],
];

const book = XLSX.utils.book_new();
const stock = XLSX.utils.aoa_to_sheet([HEADERS]);
stock['!cols'] = [14, 30, 18, 14, 14, 10, 12, 14, 26, 18].map((wch) => ({ wch }));
const help = XLSX.utils.aoa_to_sheet(instructions);
help['!cols'] = [{ wch: 22 }, { wch: 10 }, { wch: 70 }];
XLSX.utils.book_append_sheet(book, stock, 'المخزون');
XLSX.utils.book_append_sheet(book, help, 'تعليمات');
book.Workbook = { Views: [{ RTL: true }] };

const dir = join(root, 'supabase/templates');
mkdirSync(dir, { recursive: true });
const out = join(dir, 'inventory-template.xlsx');
writeFileSync(out, XLSX.write(book, { type: 'buffer', bookType: 'xlsx', compression: true }));
console.log(`wrote ${out}`);

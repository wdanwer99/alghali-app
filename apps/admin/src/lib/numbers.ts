/**
 * Numbers as people type them on an Arabic keyboard: Arabic-Indic digits (١٢٠٠), the Arabic
 * decimal mark (٫) and thousands mark (٬), a comma for thousands or for the decimal point.
 * A browser's `<input type="number">` throws Arabic digits away, so the console uses text
 * boxes and reads them with this.
 */

/** Western digits, `.` for the decimal mark and `-` for minus; everything else untouched. */
export function westernDigits(s: string): string {
  return s
    .replace(/[٠-٩]/g, (d) => String(d.charCodeAt(0) - 0x0660))
    .replace(/[۰-۹]/g, (d) => String(d.charCodeAt(0) - 0x06f0))
    .replace(/٫/g, '.')
    .replace(/[−–]/g, '-');
}

/**
 * Null when empty, NaN when it isn't a number. Whole numbers (`integer`, e.g. SDG amounts)
 * ignore commas, so "2,000" is 2000. Otherwise a lone comma is the decimal point
 * ("15,5" is 15.5); a dot already present wins.
 */
export function parseNumber(text: string, { integer = false } = {}): number | null {
  let v = westernDigits(text).replace(/[\s٬]/g, '');
  if (v === '') return null;
  if (integer) {
    v = v.replace(/,/g, '');
    return /^-?\d+$/.test(v) ? Number(v) : NaN;
  }
  if (!v.includes('.') && /^-?\d+,\d+$/.test(v)) v = v.replace(',', '.');
  return /^-?\d+(\.\d+)?$/.test(v) ? Number(v) : NaN;
}

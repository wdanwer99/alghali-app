import { describe, expect, it } from 'vitest';
import { parseNumber } from './numbers';

describe('numbers typed on an Arabic or English keyboard', () => {
  it.each([
    ['1200', 1200],
    ['١٢٠٠', 1200],
    ['۱۲۰۰', 1200], // Persian digits
    ['2,000', 2000], // thousands
    ['٢٬٠٠٠', 2000], // Arabic thousands mark
    ['10 000', 10000],
  ])('whole number %s → %d', (text, value) => {
    expect(parseNumber(text, { integer: true })).toBe(value);
  });

  it.each([
    ['5.5', 5.5],
    ['٥٫٥', 5.5],
    ['5,5', 5.5], // comma as the decimal point
    ['2.5', 2.5],
  ])('decimal %s → %d', (text, value) => {
    expect(parseNumber(text)).toBe(value);
  });

  it('is null when empty and NaN when unreadable', () => {
    expect(parseNumber('')).toBeNull();
    expect(parseNumber('  ', { integer: true })).toBeNull();
    expect(parseNumber('abc')).toBeNaN();
    expect(parseNumber('1.5', { integer: true })).toBeNaN();
    expect(parseNumber('1e5')).toBeNaN();
  });
});

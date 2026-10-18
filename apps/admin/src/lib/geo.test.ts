import { describe, expect, it } from 'vitest';
import { insideSudan, parseCoordinate, parsePoint } from './geo';

describe('one coordinate typed in a box', () => {
  it.each([
    ['15.5007', 15.5007],
    ['١٥٫٥٠٠٧', 15.5007], // Arabic-Indic digits and the Arabic decimal mark
    ['١٥.٥٠٠٧', 15.5007],
    ['15,5007', 15.5007], // comma as the decimal point
    [' 32.5599 ', 32.5599],
    ['32.5599°', 32.5599],
    ['-0.5', -0.5],
    ['−0.5', -0.5], // typographic minus
    ['15', 15],
  ])('%s → %d', (text, value) => {
    expect(parseCoordinate(text)).toBe(value);
  });

  it('is null when empty and NaN when not a number', () => {
    expect(parseCoordinate('')).toBeNull();
    expect(parseCoordinate('   ')).toBeNull();
    expect(parseCoordinate('abc')).toBeNaN();
    expect(parseCoordinate('15.5.1')).toBeNaN();
    expect(parseCoordinate('15.5, 32.5')).toBeNaN(); // a pair is not one coordinate
  });
});

describe('a whole point pasted from a map', () => {
  const khartoum = { lat: 15.5007, lng: 32.5599 };
  it.each([
    ['15.5007, 32.5599'],
    ['15.5007,32.5599'],
    ['15.5007 32.5599'],
    ['15.5007، 32.5599'], // Arabic comma
    ['١٥٫٥٠٠٧، ٣٢٫٥٥٩٩'],
    ['15,5007 32,5599'],
    ['https://www.google.com/maps/@15.5007,32.5599,17z'],
    ['https://maps.google.com/?q=15.5007,32.5599'],
  ])('%s', (text) => {
    expect(parsePoint(text)).toEqual(khartoum);
  });

  it('reads degrees, minutes and seconds', () => {
    const p = parsePoint(`15°30'02.5"N 32°33'35.6"E`);
    expect(p?.lat).toBeCloseTo(15.50069, 4);
    expect(p?.lng).toBeCloseTo(32.55989, 4);
    expect(parsePoint(`32°33'35.6"E 15°30'02.5"N`)?.lat).toBeCloseTo(15.50069, 4);
  });

  it('leaves single numbers and nonsense to an ordinary paste', () => {
    expect(parsePoint('15.5007')).toBeNull();
    expect(parsePoint('15,5007')).toBeNull(); // one comma-decimal number, not a pair
    expect(parsePoint('hello world')).toBeNull();
    expect(parsePoint('95.1, 32.5')).toBeNull(); // latitude out of range
  });
});

describe('inside Sudan', () => {
  it('flags swapped numbers', () => {
    expect(insideSudan({ lat: 15.5007, lng: 32.5599 })).toBe(true);
    expect(insideSudan({ lat: 32.5599, lng: 15.5007 })).toBe(false);
  });
});

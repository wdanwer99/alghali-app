import { describe, expect, it } from 'vitest';
import { coordinateText, insideSudan, parseCoordinate, parsePoint, readCoordinate } from './geo';

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

  it('reads Google Maps degrees-minutes-seconds, one half per box', () => {
    expect(readCoordinate(`15°34'43.5"N`)).toEqual({ value: 15.57875, axis: 'lat' });
    expect(readCoordinate(`32°32'02.0"E`)).toEqual({ value: 32.533889, axis: 'lng' });
    expect(readCoordinate(`15°34′43.5″N`).value).toBe(15.57875); // typographic primes
    expect(readCoordinate(`15º34'43.5"N`).value).toBe(15.57875); // ordinal sign for degree
    expect(readCoordinate(`١٥°٣٤'٤٣٫٥"N`).value).toBe(15.57875);
    expect(readCoordinate(`15°34'43.5"شمال`)).toEqual({ value: 15.57875, axis: 'lat' });
    expect(readCoordinate(`32°32'02.0"W`).value).toBe(-32.533889);
    expect(readCoordinate(`15°34.725'N`).value).toBe(15.57875); // degrees and decimal minutes
    expect(readCoordinate(`15.57875 N`)).toEqual({ value: 15.57875, axis: 'lat' });
    expect(readCoordinate(`15°61'N`).value).toBeNaN(); // 61 minutes isn't a thing
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
    ['15.5007N, 32.5599E'],
    ['15.5007° 32.5599°'],
  ])('%s', (text) => {
    expect(parsePoint(text)).toEqual(khartoum);
  });

  const pin = { lat: 15.57875, lng: 32.533889 };
  it.each([
    [`15°34'43.5"N 32°32'02.0"E`], // what Google Maps copies
    [`15°34′43.5″N 32°32′02.0″E`],
    [`15°34'43.5"N 32°32'02.0"E`], // no-break space
    [`15°34'43.5"N\n32°32'02.0"E`],
    [`32°32'02.0"E 15°34'43.5"N`], // longitude first
    [`15°34'43.5"N 32°32'02.0"E\nKhartoum, Sudan`], // with the address underneath
    [`١٥°٣٤'٤٣٫٥"N ٣٢°٣٢'٠٢٫٠"E`],
    [`15°34'43.5" 32°32'02.0"`], // no letters: latitude first
  ])('Google Maps pin %s', (text) => {
    expect(parsePoint(text)).toEqual(pin);
  });

  it('leaves single numbers and nonsense alone', () => {
    expect(parsePoint('15.5007')).toBeNull();
    expect(parsePoint('15,5007')).toBeNull(); // one comma-decimal number, not a pair
    expect(parsePoint(`15°34'43.5"N`)).toBeNull(); // half a pin
    expect(parsePoint('hello world')).toBeNull();
    expect(parsePoint('95.1, 32.5')).toBeNull(); // latitude out of range
  });
});

describe('showing and checking', () => {
  it('keeps 6 decimals', () => {
    expect(coordinateText(32.53388888888889)).toBe('32.533889');
    expect(coordinateText(15.5)).toBe('15.5');
  });

  it('flags swapped numbers', () => {
    expect(insideSudan({ lat: 15.5007, lng: 32.5599 })).toBe(true);
    expect(insideSudan({ lat: 32.5599, lng: 15.5007 })).toBe(false);
  });
});

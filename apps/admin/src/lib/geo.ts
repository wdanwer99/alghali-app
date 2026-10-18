/**
 * Reading GPS coordinates the way people type them in Sudan: Arabic-Indic digits
 * (١٥٫٥), the Arabic decimal mark (٫), a comma as the decimal point (15,5), a degree
 * sign, or a point pasted from Google Maps (a pin, a link, or degrees-minutes-seconds).
 */
import { parseNumber, westernDigits } from './numbers';

/** One coordinate from a text box: null when empty, NaN when it isn't a plain number. */
export function parseCoordinate(text: string): number | null {
  return parseNumber(text.replace(/°/g, ''));
}

export type Point = { lat: number; lng: number };

const inRange = (p: Point): Point | null =>
  Math.abs(p.lat) <= 90 && Math.abs(p.lng) <= 180 ? p : null;

/**
 * A whole point pasted into either box, or null when the text isn't one (then it's an
 * ordinary paste into that box). Accepts "15.5007, 32.5599", "15,5007 32,5599", the same
 * in Arabic digits, Google Maps links (…/@15.5007,32.5599,17z or ?q=15.5007,32.5599), and
 * 15°30'02.5"N 32°33'35.6"E.
 */
export function parsePoint(text: string): Point | null {
  const t = westernDigits(text).trim();

  const link = /[@=](-?\d{1,3}\.\d+),\s*(-?\d{1,3}\.\d+)/.exec(t);
  if (link) return inRange({ lat: Number(link[1]), lng: Number(link[2]) });

  const dms = [
    ...t.matchAll(
      /(\d{1,3})\s*°\s*(\d{1,2})\s*['′]\s*(?:(\d{1,2}(?:\.\d+)?)\s*["″])?\s*([NSEW])/gi,
    ),
  ];
  if (dms.length === 2) {
    const value = (m: RegExpMatchArray) => {
      const v = Number(m[1]) + Number(m[2]) / 60 + Number(m[3] ?? 0) / 3600;
      return /[SW]/i.test(m[4]) ? -v : v;
    };
    const [a, b] = dms;
    const aIsLat = /[NS]/i.test(a[4]);
    return inRange({ lat: value(aIsLat ? a : b), lng: value(aIsLat ? b : a) });
  }

  // Two plain numbers: dot decimals split by a comma, Arabic comma, semicolon or space…
  const dots = /^(-?\d{1,3}(?:\.\d+)?)\s*(?:[,،;]|\s)\s*(-?\d{1,3}(?:\.\d+)?)$/.exec(t);
  if (dots) return inRange({ lat: Number(dots[1]), lng: Number(dots[2]) });
  // …or comma decimals split by a space or semicolon ("15,5007 32,5599").
  const commas = /^(-?\d{1,3},\d+)\s*(?:;|\s)\s*(-?\d{1,3},\d+)$/.exec(t);
  if (commas) {
    return inRange({
      lat: Number(commas[1].replace(',', '.')),
      lng: Number(commas[2].replace(',', '.')),
    });
  }
  return null;
}

/** Roughly Sudan's borders; a point outside them usually means the two numbers were swapped. */
export function insideSudan({ lat, lng }: Point): boolean {
  return lat >= 8 && lat <= 23.5 && lng >= 21.5 && lng <= 39;
}

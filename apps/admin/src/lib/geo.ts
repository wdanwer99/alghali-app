/**
 * Reading GPS coordinates the way people type or copy them in Sudan: Arabic-Indic digits
 * (١٥٫٥), the Arabic decimal mark (٫), a comma as the decimal point (15,5), degrees-minutes-
 * seconds from Google Maps (15°34'43.5"N), N/S/E/W or their Arabic words, a Google Maps link,
 * or both numbers at once. Results keep 6 decimals (about 10 cm).
 */
import { parseNumber, westernDigits } from './numbers';

export type Axis = 'lat' | 'lng';
/** One coordinate: null when empty, NaN when unreadable; `axis` when N/S/E/W says which it is. */
export type Reading = { value: number | null; axis?: Axis };
export type Point = { lat: number; lng: number };

const round6 = (n: number) => Math.round(n * 1e6) / 1e6;

/** Western digits, plain ' " ° and N/S/E/W, whatever keyboard or map app produced the text. */
function tidy(text: string): string {
  return westernDigits(text)
    .replace(/[′’‘`´]/g, "'")
    .replace(/[″“”]|''/g, '"')
    .replace(/[º˚]/g, '°')
    .replace(/شمال/g, 'N')
    .replace(/جنوب/g, 'S')
    .replace(/شرق/g, 'E')
    .replace(/غرب/g, 'W')
    .replace(/ش/g, 'N')
    .replace(/ج/g, 'S')
    .replace(/ق/g, 'E')
    .replace(/غ/g, 'W');
}

const NUM = String.raw`(-?\d{1,3}(?:\.\d+)?)`;
const PART = String.raw`(\d{1,2}(?:\.\d+)?)`;
/** 15°34'43.5"N, 15°34.725'N, 15.57875°N, 15.57875° (hemisphere optional). */
const DMS = new RegExp(
  String.raw`^${NUM}\s*°\s*(?:${PART}\s*'\s*)?(?:${PART}\s*"\s*)?([NSEW])?$`,
  'i',
);
/** 15.57875 N */
const HEMI = new RegExp(String.raw`^${NUM}\s*([NSEW])$`, 'i');

function fromParts(deg: string, min?: string, sec?: string, hemi?: string): Reading {
  if (Number(min ?? 0) >= 60 || Number(sec ?? 0) >= 60) return { value: NaN };
  const sign = deg.startsWith('-') || (hemi !== undefined && /[SW]/i.test(hemi)) ? -1 : 1;
  const v = Math.abs(Number(deg)) + Number(min ?? 0) / 60 + Number(sec ?? 0) / 3600;
  const axis = hemi ? (/[NS]/i.test(hemi) ? 'lat' : 'lng') : undefined;
  return { value: round6(sign * v), axis };
}

/** One coordinate typed or pasted into a box. */
export function readCoordinate(text: string): Reading {
  const t = tidy(text).trim();
  if (t === '') return { value: null };
  const dms = DMS.exec(t);
  if (dms) return fromParts(dms[1], dms[2], dms[3], dms[4]);
  const hemi = HEMI.exec(t);
  if (hemi) return fromParts(hemi[1], undefined, undefined, hemi[2]);
  return { value: parseNumber(t) };
}

/** The number in a box: null when empty, NaN when it isn't a coordinate. */
export function parseCoordinate(text: string): number | null {
  return readCoordinate(text).value;
}

const inRange = (p: Point): Point | null =>
  Math.abs(p.lat) <= 90 && Math.abs(p.lng) <= 180 ? p : null;

/** Two halves read on their own; N/S/E/W puts each in its place whatever the order. */
function pairFrom(a: string, b: string): Point | null {
  const x = readCoordinate(a);
  const y = readCoordinate(b);
  if (x.value === null || y.value === null || Number.isNaN(x.value) || Number.isNaN(y.value)) {
    return null;
  }
  const swap = x.axis === 'lng' || y.axis === 'lat';
  return inRange(swap ? { lat: y.value, lng: x.value } : { lat: x.value, lng: y.value });
}

/**
 * A whole point in one piece of text, or null when the text isn't one (then it is one
 * coordinate, or nothing). Accepts Google Maps' 15°34'43.5"N 32°32'02.0"E (also with text
 * around it), "15.5007, 32.5599", "15,5007 32,5599", the same in Arabic digits, and Google
 * Maps links (…/@15.5007,32.5599,17z or ?q=15.5007,32.5599).
 */
export function parsePoint(text: string): Point | null {
  const t = tidy(text).trim();

  const link = /[@=](-?\d{1,3}\.\d+),\s*(-?\d{1,3}\.\d+)/.exec(t);
  if (link) return inRange({ lat: round6(Number(link[1])), lng: round6(Number(link[2])) });

  // Each half ends with N/S/E/W: "15°34'43.5"N 32°32'02.0"E", "15.5N, 32.5E".
  const hemis = /(-?\d[^NSEW]*?[NSEW])\s*[,،;]?\s*(-?\d[^NSEW]*?[NSEW])/i.exec(t);
  if (hemis) {
    const p = pairFrom(hemis[1], hemis[2]);
    if (p) return p;
  }
  // Degrees without letters: 15°34'43.5" 32°32'02.0" or 15.5007° 32.5599°.
  const degrees = /^(-?\d[^°]*°[^\s,،;]*)\s*[,،;]?\s*(-?\d[^°]*°.*)$/.exec(t);
  if (degrees) {
    const p = pairFrom(degrees[1], degrees[2]);
    if (p) return p;
  }
  // Two plain numbers: dot decimals split by a comma, Arabic comma, semicolon or space…
  const dots = /^(-?\d{1,3}(?:\.\d+)?)\s*(?:[,،;]|\s)\s*(-?\d{1,3}(?:\.\d+)?)$/.exec(t);
  if (dots) return inRange({ lat: round6(Number(dots[1])), lng: round6(Number(dots[2])) });
  // …or comma decimals split by a space or semicolon ("15,5007 32,5599").
  const commas = /^(-?\d{1,3},\d+)\s*(?:;|\s)\s*(-?\d{1,3},\d+)$/.exec(t);
  if (commas) return pairFrom(commas[1], commas[2]);
  return null;
}

/** A coordinate as it's shown and saved: at most 6 decimals. */
export function coordinateText(n: number): string {
  return String(round6(n));
}

/** Roughly Sudan's borders; a point outside them usually means the two numbers were swapped. */
export function insideSudan({ lat, lng }: Point): boolean {
  return lat >= 8 && lat <= 23.5 && lng >= 21.5 && lng <= 39;
}

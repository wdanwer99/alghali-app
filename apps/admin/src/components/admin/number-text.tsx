'use client';

import { useState, type ComponentProps } from 'react';
import { parseNumber } from '@/lib/numbers';

const show = (n: number) => (Number.isNaN(n) ? '' : String(n));
const same = (a: number, b: number) => a === b || (Number.isNaN(a) && Number.isNaN(b));

/**
 * A number box that understands an Arabic keyboard (١٢٠٠, ٫, ٬) and commas, which
 * `<input type="number">` silently drops. It keeps what was typed, reports the number
 * (NaN while empty or unreadable), and shows the number in Western digits on leaving.
 * `integer` boxes (SDG, metres, minutes) read "2,000" as two thousand.
 */
export function NumberText({
  value,
  onChange,
  integer = false,
  ...props
}: Omit<ComponentProps<'input'>, 'value' | 'onChange' | 'type'> & {
  value: number;
  onChange: (n: number) => void;
  integer?: boolean;
}) {
  const [text, setText] = useState(() => show(value));
  const [prev, setPrev] = useState(value);
  const parsed = parseNumber(text, { integer }) ?? NaN;
  // Follow changes from outside (Discard, a new band) without fighting the typing.
  if (!same(prev, value)) {
    setPrev(value);
    if (!same(parsed, value)) setText(show(value));
  }
  return (
    <input
      type="text"
      dir="ltr"
      inputMode={integer ? 'numeric' : 'decimal'}
      autoComplete="off"
      {...props}
      value={text}
      onChange={(e) => {
        setText(e.target.value);
        onChange(parseNumber(e.target.value, { integer }) ?? NaN);
      }}
      onBlur={(e) => {
        if (!Number.isNaN(parsed) && show(parsed) !== text) setText(show(parsed));
        props.onBlur?.(e);
      }}
    />
  );
}

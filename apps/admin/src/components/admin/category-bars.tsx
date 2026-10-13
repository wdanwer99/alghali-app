'use client';

import { motion } from 'motion/react';
import { useState } from 'react';
import { cn } from 'cn';
import { easeOut } from '@/components/motion';

type Row = { id: string; label: string; value: number; note: string };

/**
 * Horizontal bars, one series (`--chart-1`), sorted largest first. Bars grow in
 * once when they scroll into view; hovering one dims the rest. Every value is
 * printed, so the list doubles as its own table (dataviz skill).
 */
export function CategoryBars({ rows, label }: { rows: Row[]; label: string }) {
  const [hover, setHover] = useState<string | null>(null);
  const max = Math.max(1, ...rows.map((r) => r.value));
  return (
    <ul aria-label={label} className="flex flex-col gap-1 px-2 py-3">
      {rows.map((r, i) => (
        <li
          key={r.id}
          onMouseEnter={() => setHover(r.id)}
          onMouseLeave={() => setHover(null)}
          className={cn(
            'grid grid-cols-[minmax(6rem,9rem)_1fr_auto] items-center gap-3 rounded-lg px-2 py-1.5 transition-opacity duration-200',
            hover && hover !== r.id && 'opacity-50',
          )}
        >
          <span className="truncate text-sm font-medium" title={r.label}>
            {r.label}
          </span>
          <span className="relative h-6 overflow-hidden rounded-md bg-muted/70">
            <motion.span
              className="absolute inset-y-0 start-0 rounded-md bg-chart-1 ltr:origin-left rtl:origin-right"
              style={{ width: `${(r.value / max) * 100}%` }}
              initial={{ scaleX: 0 }}
              whileInView={{ scaleX: 1 }}
              viewport={{ once: true }}
              transition={{ duration: 0.7, delay: i * 0.05, ease: easeOut }}
            />
          </span>
          <span className="min-w-14 text-end text-sm leading-tight">
            <span className="block font-semibold tabular-nums">{r.value}</span>
            <span className="block text-xs text-muted-foreground">{r.note}</span>
          </span>
        </li>
      ))}
    </ul>
  );
}

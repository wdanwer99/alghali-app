'use client';

import { BarChart3, Download, TableProperties } from 'lucide-react';
import { motion } from 'motion/react';
import { useState } from 'react';
import { cn } from 'cn';
import { easeOut } from '@/components/motion';
import { Button } from '@/components/ui/button';
import { Num, Table, Td, Th } from './ui';

export type DayPoint = {
  /** Shown under the bar and in the table, already formatted. */
  label: string;
  value: number;
  /** The value as text ("SDG 45,000"). */
  valueText: string;
  /** Secondary figure for the tooltip and table ("3 orders"). */
  note: string;
};

/**
 * Columns, one per day, one series (`--chart-1`). Hovering or focusing a day shows its
 * figures; the table view lists every day, so nothing depends on hovering (dataviz skill).
 */
export function DailyChart({
  points,
  label,
  chartLabel,
  tableLabel,
  dayHeader,
  valueHeader,
  noteHeader,
}: {
  points: DayPoint[];
  label: string;
  chartLabel: string;
  tableLabel: string;
  dayHeader: string;
  valueHeader: string;
  noteHeader: string;
}) {
  const [table, setTable] = useState(false);
  const [active, setActive] = useState<number | null>(null);
  const max = Math.max(1, ...points.map((p) => p.value));
  const shown = active === null ? null : points[active];
  // Label every day when few, else about seven labels.
  const every = Math.max(1, Math.ceil(points.length / 7));

  return (
    <div className="flex flex-col gap-3 p-4">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <p className="min-h-5 text-sm text-muted-foreground" aria-live="polite">
          {shown ? (
            <>
              <span className="font-semibold text-foreground">{shown.label}</span> ·{' '}
              <Num>{shown.valueText}</Num> · {shown.note}
            </>
          ) : null}
        </p>
        <Button variant="outline" size="sm" onClick={() => setTable((t) => !t)}>
          {table ? <BarChart3 aria-hidden /> : <TableProperties aria-hidden />}
          {table ? chartLabel : tableLabel}
        </Button>
      </div>
      {table ? (
        <div className="max-h-96 overflow-auto">
          <Table>
            <thead>
              <tr>
                <Th>{dayHeader}</Th>
                <Th className="text-end">{valueHeader}</Th>
                <Th className="text-end">{noteHeader}</Th>
              </tr>
            </thead>
            <tbody>
              {points.map((p) => (
                <tr key={p.label}>
                  <Td>{p.label}</Td>
                  <Td className="text-end">
                    <Num>{p.valueText}</Num>
                  </Td>
                  <Td className="text-end text-muted-foreground">{p.note}</Td>
                </tr>
              ))}
            </tbody>
          </Table>
        </div>
      ) : (
        <div role="img" aria-label={label} className="flex flex-col gap-1">
          <div className="flex h-48 items-end gap-[2px] border-b border-border">
            {points.map((p, i) => (
              <button
                key={p.label}
                type="button"
                aria-label={`${p.label}: ${p.valueText}, ${p.note}`}
                onMouseEnter={() => setActive(i)}
                onMouseLeave={() => setActive(null)}
                onFocus={() => setActive(i)}
                onBlur={() => setActive(null)}
                className="group flex h-full flex-1 items-end focus-visible:outline-none"
              >
                <motion.span
                  className={cn(
                    'mx-auto w-full max-w-6 origin-bottom rounded-t-[4px] bg-chart-1 transition-opacity',
                    active !== null && active !== i && 'opacity-45',
                    'group-focus-visible:ring-2 group-focus-visible:ring-ring',
                  )}
                  style={{ height: `${Math.max((p.value / max) * 100, p.value > 0 ? 2 : 0)}%` }}
                  initial={{ scaleY: 0 }}
                  animate={{ scaleY: 1 }}
                  transition={{ duration: 0.5, delay: Math.min(i * 0.01, 0.4), ease: easeOut }}
                />
              </button>
            ))}
          </div>
          <div className="flex gap-[2px]" aria-hidden>
            {points.map((p, i) => (
              <span
                key={p.label}
                className="flex-1 truncate text-center text-[11px] text-muted-foreground"
              >
                {i % every === 0 ? p.label : ''}
              </span>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

/** Saves [rows] as a CSV file that Excel opens with Arabic intact (UTF-8 with a BOM). */
export function CsvButton({
  rows,
  fileName,
  label,
}: {
  rows: (string | number)[][];
  fileName: string;
  label: string;
}) {
  const download = () => {
    const cell = (v: string | number) => {
      const s = String(v);
      return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
    };
    const text = '﻿' + rows.map((r) => r.map(cell).join(',')).join('\r\n');
    const url = URL.createObjectURL(new Blob([text], { type: 'text/csv;charset=utf-8' }));
    const a = document.createElement('a');
    a.href = url;
    a.download = fileName;
    a.click();
    URL.revokeObjectURL(url);
  };
  return (
    <Button variant="outline" onClick={download}>
      <Download aria-hidden />
      {label}
    </Button>
  );
}

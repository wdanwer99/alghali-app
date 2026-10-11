'use client';

import { ChartColumn, Table2 } from 'lucide-react';
import { useEffect, useRef, useState } from 'react';

/** `short` is the axis label (day of month), `full` the tooltip/table label; both pre-formatted on the server. */
type Point = { key: string; short: string; full: string; orders: number };
type Labels = {
  title: string;
  total: string;
  showTable: string;
  showChart: string;
  day: string;
  orders: string;
};

const H = 220;
const AXIS = 40;
const TOP = 16;
const BASE = H - 28;

function niceMax(v: number) {
  for (const step of [5, 10, 20, 25, 50, 100])
    if (v / step <= 4) return { step, top: Math.ceil(v / step) * step };
  return { step: 100, top: Math.ceil(v / 100) * 100 };
}

/**
 * One series → one validated colour (`--chart-1`), no legend (the title
 * names it); ≤24 px columns with a 4 px rounded data end, hairline grid,
 * per-bar hover/focus tooltip, and a table view twin (dataviz skill).
 * The SVG is drawn at its real pixel width so labels stay 11 px on phones.
 */
export function OrdersChart({
  data,
  labels,
  rtl,
}: {
  data: Point[];
  labels: Labels;
  rtl: boolean;
}) {
  const [table, setTable] = useState(false);
  const [hover, setHover] = useState<number | null>(null);
  const [W, setW] = useState(640);
  const boxRef = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const el = boxRef.current;
    if (!el) return;
    const observer = new ResizeObserver(([entry]) =>
      setW(Math.max(280, Math.round(entry.contentRect.width))),
    );
    observer.observe(el);
    return () => observer.disconnect();
  }, [table]);
  const { step, top } = niceMax(Math.max(...data.map((d) => d.orders)));
  const plotW = W - AXIS;
  const slot = plotW / data.length;
  const barW = Math.min(24, slot * 0.55);
  const y = (v: number) => BASE - ((BASE - TOP) * v) / top;
  const xOf = (i: number) => {
    const left = rtl ? 0 : AXIS;
    const ordinal = rtl ? data.length - 1 - i : i;
    return left + slot * ordinal + slot / 2;
  };

  return (
    <section className="rounded-xl bg-card ring-1 ring-foreground/10">
      <div className="flex flex-wrap items-start justify-between gap-3 border-b px-4 py-3">
        <div>
          <h2 className="text-base font-semibold">{labels.title}</h2>
          <p className="text-sm text-muted-foreground">{labels.total}</p>
        </div>
        <button
          type="button"
          onClick={() => setTable((v) => !v)}
          className="inline-flex h-8 items-center gap-1.5 rounded-lg px-2.5 text-sm font-medium hover:bg-muted focus-visible:ring-2 focus-visible:ring-ring focus-visible:outline-none"
        >
          {table ? <ChartColumn className="size-4" /> : <Table2 className="size-4" />}
          {table ? labels.showChart : labels.showTable}
        </button>
      </div>

      {table ? (
        <div className="max-h-80 overflow-y-auto px-4 py-2">
          <table className="w-full text-sm">
            <thead>
              <tr>
                <th scope="col" className="py-2 text-start font-semibold text-muted-foreground">
                  {labels.day}
                </th>
                <th scope="col" className="py-2 text-end font-semibold text-muted-foreground">
                  {labels.orders}
                </th>
              </tr>
            </thead>
            <tbody>
              {data.map((d) => (
                <tr key={d.key} className="border-t">
                  <td className="py-2">{d.full}</td>
                  <td className="py-2 text-end tabular-nums">{d.orders}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      ) : (
        <div ref={boxRef} className="relative mx-2 my-3">
          <svg
            viewBox={`0 0 ${W} ${H}`}
            className="block h-auto w-full"
            role="group"
            aria-label={labels.title}
          >
            {Array.from({ length: top / step + 1 }, (_, k) => k * step).map((v) => (
              <g key={v}>
                <line
                  x1={rtl ? 0 : AXIS}
                  x2={rtl ? plotW : W}
                  y1={y(v)}
                  y2={y(v)}
                  className="stroke-border"
                  strokeWidth={1}
                />
                <text
                  x={rtl ? W - 4 : AXIS - 8}
                  y={y(v)}
                  dy="0.35em"
                  textAnchor="end"
                  className="fill-muted-foreground text-[11px] tabular-nums"
                  direction="ltr"
                >
                  {v}
                </text>
              </g>
            ))}
            {data.map((d, i) => {
              const cx = xOf(i);
              const h = BASE - y(d.orders);
              const r = Math.min(4, h);
              return (
                <g
                  key={d.key}
                  tabIndex={0}
                  role="img"
                  aria-label={`${d.full}: ${d.orders}`}
                  onMouseEnter={() => setHover(i)}
                  onMouseLeave={() => setHover(null)}
                  onFocus={() => setHover(i)}
                  onBlur={() => setHover(null)}
                  className="cursor-default outline-none"
                >
                  {/* Hit target wider than the mark. */}
                  <rect
                    x={cx - slot / 2}
                    y={TOP}
                    width={slot}
                    height={BASE - TOP}
                    fill="transparent"
                  />
                  <path
                    d={`M${cx - barW / 2},${BASE} V${BASE - h + r} Q${cx - barW / 2},${BASE - h} ${cx - barW / 2 + r},${BASE - h} H${cx + barW / 2 - r} Q${cx + barW / 2},${BASE - h} ${cx + barW / 2},${BASE - h + r} V${BASE} Z`}
                    className="fill-chart-1 transition-opacity"
                    opacity={hover === null || hover === i ? 1 : 0.45}
                  />
                  <text
                    x={cx}
                    y={BASE + 18}
                    textAnchor="middle"
                    className={
                      i === data.length - 1
                        ? 'fill-foreground text-[11px] font-bold'
                        : 'fill-muted-foreground text-[11px]'
                    }
                  >
                    {d.short}
                  </text>
                </g>
              );
            })}
          </svg>
          {hover !== null && (
            <div
              className="pointer-events-none absolute rounded-md bg-foreground px-2 py-1 text-xs text-background shadow-sm"
              style={{
                left: Math.min(Math.max(xOf(hover), 64), W - 64),
                top: y(data[hover].orders),
                transform: 'translate(-50%, -120%)',
              }}
            >
              <div className="font-bold tabular-nums">{data[hover].orders}</div>
              <div className="opacity-80">{data[hover].full}</div>
            </div>
          )}
        </div>
      )}
    </section>
  );
}

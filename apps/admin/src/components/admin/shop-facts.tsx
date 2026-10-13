import { MapPin, MessageCircle, Phone, UserRound } from 'lucide-react';
import type { ReactNode } from 'react';
import type { Locale } from '@/i18n/config';
import type { Dictionary } from '@/i18n/dictionaries';
import type { Shop } from '@/lib/data/shops';
import { named } from '@/lib/data/util';
import { fill, ltr } from '@/lib/format';

/** Readable phone: "+249 912 000 001", kept left-to-right inside Arabic text. */
export function phoneText(e164: string): string {
  const m = /^\+249(\d{3})(\d{3})(\d{3})$/.exec(e164);
  return ltr(m ? `+249 ${m[1]} ${m[2]} ${m[3]}` : e164);
}

/** "Zone 2 · Plot 12 · Side A · Opposite the fuel station". */
export function shopPlace(s: Shop, locale: Locale, d: Dictionary['approvals']): string {
  return [
    named(s.zone, locale),
    s.plotNo && fill(d.plot, { n: s.plotNo }),
    s.side && fill(d.side, { s: s.side }),
    s.landmark && named(s.landmark, locale),
  ]
    .filter(Boolean)
    .join(' · ');
}

function Fact({ icon, children }: { icon: ReactNode; children: ReactNode }) {
  return (
    <li className="flex items-start gap-2.5 text-sm">
      <span className="mt-0.5 text-muted-foreground [&_svg]:size-4">{icon}</span>
      <span className="min-w-0 flex-1">{children}</span>
    </li>
  );
}

/** Where the shop is, who owns it, how to reach it and what it sells. */
export function ShopFacts({
  shop: s,
  locale,
  d,
  common,
}: {
  shop: Shop;
  locale: Locale;
  d: Dictionary['approvals'];
  common: Dictionary['common'];
}) {
  return (
    <div className="flex flex-col gap-4">
      <ul className="flex flex-col gap-2">
        <Fact icon={<MapPin />}>{shopPlace(s, locale, d)}</Fact>
        {s.owner && (
          <Fact icon={<UserRound />}>
            <span className="font-medium">{s.owner.name}</span>
            <span className="text-muted-foreground"> · </span>
            <a
              dir="ltr"
              href={`mailto:${s.owner.email}`}
              className="text-muted-foreground underline-offset-2 hover:underline"
            >
              {s.owner.email}
            </a>
          </Fact>
        )}
        {s.phone && (
          <Fact icon={<Phone />}>
            <a
              href={`tel:${s.phone}`}
              className="underline-offset-2 hover:underline"
              aria-label={`${common.phone} ${s.phone}`}
            >
              {phoneText(s.phone)}
            </a>
          </Fact>
        )}
        {s.whatsapp && (
          <Fact icon={<MessageCircle />}>
            <a
              href={`https://wa.me/${s.whatsapp.replace('+', '')}`}
              target="_blank"
              rel="noreferrer"
              className="underline-offset-2 hover:underline"
              aria-label={`${common.whatsapp} ${s.whatsapp}`}
            >
              {phoneText(s.whatsapp)}
            </a>
          </Fact>
        )}
      </ul>
      {(s.categories.length > 0 || s.makes.length > 0) && (
        <div className="flex flex-col gap-2">
          {s.categories.length > 0 && (
            <Chips label={d.sells} items={s.categories.map((c) => named(c, locale))} />
          )}
          {s.makes.length > 0 && (
            <Chips label={d.makes} items={s.makes.map((m) => named(m, locale))} />
          )}
        </div>
      )}
      {s.about && (
        <div>
          <h4 className="text-xs font-semibold text-muted-foreground">{d.about}</h4>
          <p className="mt-1 text-sm leading-relaxed">{named(s.about, locale)}</p>
        </div>
      )}
    </div>
  );
}

function Chips({ label, items }: { label: string; items: string[] }) {
  return (
    <div className="flex flex-wrap items-center gap-1.5">
      <span className="me-1 text-xs font-semibold text-muted-foreground">{label}</span>
      {items.map((x) => (
        <span key={x} className="rounded-md bg-muted px-2 py-0.5 text-xs font-medium">
          {x}
        </span>
      ))}
    </div>
  );
}

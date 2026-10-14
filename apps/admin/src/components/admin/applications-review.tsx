'use client';

import { Tabs } from '@base-ui/react/tabs';
import { Check, Inbox, Phone, Store, Wrench, X } from 'lucide-react';
import { AnimatePresence, motion } from 'motion/react';
import Link from 'next/link';
import { useState, type ReactNode } from 'react';
import { Button, buttonVariants } from '@/components/ui/button';
import type { Locale } from '@/i18n/config';
import type { Dictionary } from '@/i18n/dictionaries';
import { setShopStatus } from '@/lib/actions/admin';
import { setTechnicianStatus } from '@/lib/actions/installation';
import type { TechnicianApplication } from '@/lib/data/installation';
import type { Shop } from '@/lib/data/shops';
import { named } from '@/lib/data/util';
import { fill, money } from '@/lib/format';
import { ConfirmDialog } from './interactive';
import { phoneText, ShopFacts } from './shop-facts';
import { useAction } from './use-action';
import { CountPill, EmptyState, StatusBadge, TabList, tabClass } from './ui';

type Labels = Dictionary['approvals'];
type Common = Dictionary['common'];

export type PendingShop = { shop: Shop; submitted: string };
export type PendingTechnician = { technician: TechnicianApplication; submitted: string };

const modeLabel = { BAY: 'modeBay', MOBILE: 'modeMobile', BOTH: 'modeBoth' } as const;

type Rejecting =
  { kind: 'shop'; shop: Shop } | { kind: 'technician'; technician: TechnicianApplication };

export function ApplicationsReview({
  locale,
  d,
  common,
  errors,
  pendingLabel,
  shops,
  technicians,
}: {
  locale: Locale;
  d: Labels;
  common: Common;
  errors: Dictionary['errors'];
  pendingLabel: string;
  shops: PendingShop[];
  technicians: PendingTechnician[];
}) {
  // Cards leave the moment an admin decides; they come back if the server says no.
  const [decided, setDecided] = useState<Set<string>>(new Set());
  const [rejecting, setRejecting] = useState<Rejecting | null>(null);
  const { pending, run } = useAction(errors);
  const open = shops.filter((x) => !decided.has(x.shop.id));
  const openTechs = technicians.filter((x) => !decided.has(x.technician.id));

  const hide = (id: string) => setDecided((s) => new Set(s).add(id));
  const restore = (id: string) =>
    setDecided((s) => {
      const next = new Set(s);
      next.delete(id);
      return next;
    });

  const approve = (shop: Shop) => {
    hide(shop.id);
    run(() => setShopStatus(shop.id, 'APPROVED'), {
      success: fill(d.approved, { shop: named(shop.name, locale) }),
      onFail: () => restore(shop.id),
    });
  };

  const approveTech = (t: TechnicianApplication) => {
    hide(t.id);
    run(() => setTechnicianStatus(t.id, 'APPROVED'), {
      success: fill(d.techApproved, { name: t.name }),
      onFail: () => restore(t.id),
    });
  };

  const reject = (r: Rejecting, reason: string) => {
    setRejecting(null);
    if (r.kind === 'shop') {
      hide(r.shop.id);
      run(() => setShopStatus(r.shop.id, 'REJECTED', reason), {
        success: fill(d.rejectedToast, { shop: named(r.shop.name, locale) }),
        onFail: () => restore(r.shop.id),
      });
    } else {
      hide(r.technician.id);
      run(() => setTechnicianStatus(r.technician.id, 'REJECTED', reason), {
        success: fill(d.techRejected, { name: r.technician.name }),
        onFail: () => restore(r.technician.id),
      });
    }
  };

  const decide = (onApprove: () => void, onReject: () => void) => (
    <div className="mt-auto flex flex-wrap gap-2 border-t px-4 py-3">
      <Button className="h-10 px-4" disabled={pending} onClick={onApprove}>
        <Check />
        {common.approve}
      </Button>
      <Button variant="outline" className="h-10 px-4" disabled={pending} onClick={onReject}>
        <X />
        {common.reject}
      </Button>
    </div>
  );

  return (
    <>
      <Tabs.Root defaultValue="shops">
        <TabList>
          <Tabs.Tab value="shops" className={tabClass}>
            {d.shops}
            <CountPill>{open.length}</CountPill>
          </Tabs.Tab>
          <Tabs.Tab value="technicians" className={tabClass}>
            {d.technicians}
            <CountPill>{openTechs.length}</CountPill>
          </Tabs.Tab>
        </TabList>

        <Tabs.Panel value="shops" className="pt-5 outline-none">
          {open.length === 0 ? (
            <div className="rounded-xl bg-card ring-1 ring-foreground/10">
              <EmptyState
                icon={<Inbox />}
                title={d.empty}
                body={d.emptyBody}
                action={
                  <Link
                    href={`/${locale}/shops`}
                    className={buttonVariants({ variant: 'outline', className: 'h-9 px-3' })}
                  >
                    {d.seeShops}
                  </Link>
                }
              />
            </div>
          ) : (
            <Cards>
              {open.map(({ shop, submitted }) => (
                <Card key={shop.id}>
                  <div className="flex items-start gap-3 p-4">
                    <span className="grid size-10 shrink-0 place-items-center rounded-lg bg-muted">
                      <Store className="size-5" aria-hidden />
                    </span>
                    <div className="min-w-0 flex-1">
                      <h3 className="text-base font-semibold">{named(shop.name, locale)}</h3>
                      {shop.name.en !== shop.name.ar && (
                        <p
                          className="text-sm text-muted-foreground"
                          lang={locale === 'ar' ? 'en' : 'ar'}
                        >
                          {locale === 'ar' ? shop.name.en : shop.name.ar}
                        </p>
                      )}
                      <p className="mt-1 text-xs text-muted-foreground">
                        {d.submitted}: {submitted}
                      </p>
                    </div>
                    <StatusBadge tone="warning">{pendingLabel}</StatusBadge>
                  </div>
                  <div className="border-t px-4 py-3">
                    <ShopFacts shop={shop} locale={locale} d={d} common={common} />
                  </div>
                  {decide(
                    () => approve(shop),
                    () => setRejecting({ kind: 'shop', shop }),
                  )}
                </Card>
              ))}
            </Cards>
          )}
        </Tabs.Panel>

        <Tabs.Panel value="technicians" className="pt-5 outline-none">
          {openTechs.length === 0 ? (
            <div className="rounded-xl bg-card ring-1 ring-foreground/10">
              <EmptyState icon={<Inbox />} title={d.emptyTech} body={d.emptyTechBody} />
            </div>
          ) : (
            <Cards>
              {openTechs.map(({ technician: t, submitted }) => (
                <Card key={t.id}>
                  <div className="flex items-start gap-3 p-4">
                    <span className="grid size-10 shrink-0 place-items-center rounded-lg bg-muted">
                      <Wrench className="size-5" aria-hidden />
                    </span>
                    <div className="min-w-0 flex-1">
                      <h3 className="text-base font-semibold">
                        <bdi>{t.name}</bdi>
                      </h3>
                      {t.phone && (
                        <a
                          href={`tel:${t.phone}`}
                          className="inline-flex items-center gap-1.5 text-sm text-muted-foreground hover:underline"
                        >
                          <Phone className="size-3.5" aria-hidden />
                          {phoneText(t.phone)}
                        </a>
                      )}
                      <p className="mt-1 text-xs text-muted-foreground">
                        {d.submitted}: {submitted}
                      </p>
                    </div>
                    <StatusBadge tone="warning">{pendingLabel}</StatusBadge>
                  </div>
                  <dl className="grid grid-cols-2 gap-3 border-t px-4 py-3 text-sm">
                    <Fact label={d.mode}>
                      {d[modeLabel[t.mode]]}
                      {t.mode !== 'BAY' && (
                        <span className="block text-xs font-normal text-muted-foreground">
                          {fill(d.radius, { n: t.radiusKm })}
                        </span>
                      )}
                    </Fact>
                    <Fact label={d.experience}>{fill(d.years, { n: t.years })}</Fact>
                    {t.bay && <Fact label={d.bay}>{named(t.bay, locale)}</Fact>}
                    <Fact label={d.makes}>
                      {t.makes.length
                        ? t.makes.map((m) => named(m, locale)).join(locale === 'ar' ? '، ' : ', ')
                        : d.allMakes}
                    </Fact>
                    <Fact label={d.hours}>
                      {t.rulesCount ? fill(d.hoursSet, { n: t.rulesCount }) : d.noHours}
                    </Fact>
                  </dl>
                  <div className="border-t px-4 py-3">
                    <h4 className="text-xs font-semibold text-muted-foreground">{d.jobs}</h4>
                    <ul className="mt-2 flex flex-col gap-1.5">
                      {t.jobs.map((j, i) => (
                        <li key={i} className="flex items-center justify-between gap-2 text-sm">
                          <span>{named(j.name, locale)}</span>
                          <span className="text-muted-foreground tabular-nums">
                            {d.labour}: {money(j.labourSdg, common.currency)}
                          </span>
                        </li>
                      ))}
                    </ul>
                    {t.bio && <p className="mt-3 text-sm text-muted-foreground">{t.bio}</p>}
                  </div>
                  {decide(
                    () => approveTech(t),
                    () => setRejecting({ kind: 'technician', technician: t }),
                  )}
                </Card>
              ))}
            </Cards>
          )}
        </Tabs.Panel>
      </Tabs.Root>

      <ConfirmDialog
        open={rejecting !== null}
        onOpenChange={(o) => !o && setRejecting(null)}
        title={
          rejecting?.kind === 'shop'
            ? fill(d.rejectTitle, { shop: named(rejecting.shop.name, locale) })
            : rejecting?.kind === 'technician'
              ? fill(d.techRejectTitle, { name: rejecting.technician.name })
              : ''
        }
        description={rejecting?.kind === 'technician' ? d.techRejectBody : d.rejectBody}
        reasonLabel={d.reason}
        reasonPlaceholder={
          rejecting?.kind === 'technician' ? d.techReasonPlaceholder : d.reasonPlaceholder
        }
        confirmLabel={common.reject}
        cancelLabel={common.cancel}
        tone="danger"
        pending={pending}
        onConfirm={(reason) => rejecting && reject(rejecting, reason)}
      />
    </>
  );
}

function Cards({ children }: { children: ReactNode }) {
  return (
    <motion.div layout className="grid grid-cols-1 items-start gap-4 md:grid-cols-2">
      <AnimatePresence mode="popLayout" initial={false}>
        {children}
      </AnimatePresence>
    </motion.div>
  );
}

function Card({ children }: { children: ReactNode }) {
  return (
    <motion.article
      layout
      initial={{ opacity: 0, y: 12 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, scale: 0.95, transition: { duration: 0.2 } }}
      className="flex flex-col rounded-xl bg-card ring-1 ring-foreground/10"
    >
      {children}
    </motion.article>
  );
}

function Fact({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div>
      <dt className="text-xs text-muted-foreground">{label}</dt>
      <dd className="font-medium">{children}</dd>
    </div>
  );
}

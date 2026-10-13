'use client';

import { Tabs } from '@base-ui/react/tabs';
import { Check, FileCheck, FileX, Inbox, Store, Wrench, X } from 'lucide-react';
import { AnimatePresence, motion } from 'motion/react';
import Link from 'next/link';
import { useState } from 'react';
import { Button, buttonVariants } from '@/components/ui/button';
import type { Locale } from '@/i18n/config';
import type { Dictionary } from '@/i18n/dictionaries';
import { setShopStatus } from '@/lib/actions/admin';
import type { Application } from '@/lib/demo/data';
import { tr } from '@/lib/demo/data';
import type { Shop } from '@/lib/data/shops';
import { named } from '@/lib/data/util';
import { fill } from '@/lib/format';
import { ConfirmDialog } from './interactive';
import { ShopFacts } from './shop-facts';
import { useAction } from './use-action';
import {
  CountPill,
  EmptyState,
  SampleBanner,
  SampleTag,
  StatusBadge,
  TabList,
  tabClass,
} from './ui';

type Labels = Dictionary['approvals'];
type Common = Dictionary['common'];

export type PendingShop = { shop: Shop; submitted: string };
export type SampleApplication = Application & { submitted: string };

const docLabel = {
  license: 'docLicense',
  id: 'docId',
  photos: 'docPhotos',
  certificate: 'docCertificate',
} as const;
const modeLabel = { bay: 'modeBay', mobile: 'modeMobile', both: 'modeBoth' } as const;

export function ApplicationsReview({
  locale,
  d,
  common,
  errors,
  sample,
  shops,
  technicians,
}: {
  locale: Locale;
  d: Labels;
  common: Common;
  errors: Dictionary['errors'];
  sample: {
    tag: string;
    title: string;
    body: string;
    statuses: Dictionary['status']['application'];
  };
  shops: PendingShop[];
  technicians: SampleApplication[];
}) {
  // Cards leave the moment an admin decides; they come back if the server says no.
  const [decided, setDecided] = useState<Set<string>>(new Set());
  const [rejecting, setRejecting] = useState<Shop | null>(null);
  const { pending, run } = useAction(errors);
  const open = shops.filter((x) => !decided.has(x.shop.id));

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

  const reject = (shop: Shop, reason: string) => {
    setRejecting(null);
    hide(shop.id);
    run(() => setShopStatus(shop.id, 'REJECTED', reason), {
      success: fill(d.rejectedToast, { shop: named(shop.name, locale) }),
      onFail: () => restore(shop.id),
    });
  };

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
            <SampleTag label={sample.tag} className="text-muted-foreground" />
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
            <motion.div layout className="grid grid-cols-1 items-start gap-4 md:grid-cols-2">
              <AnimatePresence mode="popLayout" initial={false}>
                {open.map(({ shop, submitted }) => (
                  <motion.article
                    key={shop.id}
                    layout
                    initial={{ opacity: 0, y: 12 }}
                    animate={{ opacity: 1, y: 0 }}
                    exit={{ opacity: 0, scale: 0.95, transition: { duration: 0.2 } }}
                    className="flex flex-col rounded-xl bg-card ring-1 ring-foreground/10"
                  >
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
                      <StatusBadge tone="warning">{sample.statuses.pending}</StatusBadge>
                    </div>
                    <div className="border-t px-4 py-3">
                      <ShopFacts shop={shop} locale={locale} d={d} common={common} />
                    </div>
                    <div className="mt-auto flex flex-wrap gap-2 border-t px-4 py-3">
                      <Button
                        className="h-10 px-4"
                        disabled={pending}
                        onClick={() => approve(shop)}
                      >
                        <Check />
                        {common.approve}
                      </Button>
                      <Button
                        variant="outline"
                        className="h-10 px-4"
                        disabled={pending}
                        onClick={() => setRejecting(shop)}
                      >
                        <X />
                        {common.reject}
                      </Button>
                    </div>
                  </motion.article>
                ))}
              </AnimatePresence>
            </motion.div>
          )}
        </Tabs.Panel>

        <Tabs.Panel value="technicians" className="flex flex-col gap-4 pt-5 outline-none">
          <SampleBanner title={sample.title} body={sample.body} />
          <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
            {technicians.map((a) => (
              <TechnicianCard
                key={a.id}
                a={a}
                locale={locale}
                d={d}
                common={common}
                statuses={sample.statuses}
              />
            ))}
          </div>
        </Tabs.Panel>
      </Tabs.Root>

      <ConfirmDialog
        open={rejecting !== null}
        onOpenChange={(o) => !o && setRejecting(null)}
        title={rejecting ? fill(d.rejectTitle, { shop: named(rejecting.name, locale) }) : ''}
        description={d.rejectBody}
        reasonLabel={d.reason}
        reasonPlaceholder={d.reasonPlaceholder}
        confirmLabel={common.reject}
        cancelLabel={common.cancel}
        tone="danger"
        pending={pending}
        onConfirm={(reason) => rejecting && reject(rejecting, reason)}
      />
    </>
  );
}

/** Sample technician application; decisions stay in the browser. */
function TechnicianCard({
  a,
  locale,
  d,
  common,
  statuses,
}: {
  a: SampleApplication;
  locale: Locale;
  d: Labels;
  common: Common;
  statuses: Dictionary['status']['application'];
}) {
  const [decision, setDecision] = useState<'approved' | 'rejected' | null>(null);
  const missing = a.docs.filter((doc) => !doc.ok);
  return (
    <article className="flex flex-col rounded-xl bg-card ring-1 ring-foreground/10">
      <div className="flex items-start gap-3 p-4">
        <span className="grid size-10 shrink-0 place-items-center rounded-lg bg-muted">
          <Wrench className="size-5" aria-hidden />
        </span>
        <div className="min-w-0 flex-1">
          <h3 className="text-base font-semibold">{tr(a.name, locale)}</h3>
          <p className="text-sm text-muted-foreground">{tr(a.detail, locale)}</p>
          <p className="mt-1 text-xs text-muted-foreground">
            {d.submitted}: {a.submitted}
          </p>
        </div>
        <StatusBadge
          tone={
            decision === 'approved' ? 'success' : decision === 'rejected' ? 'neutral' : 'warning'
          }
        >
          {statuses[decision ?? 'pending']}
        </StatusBadge>
      </div>
      <dl className="grid grid-cols-2 gap-3 border-t px-4 py-3 text-sm">
        {a.mode && (
          <div>
            <dt className="text-xs text-muted-foreground">{d.mode}</dt>
            <dd className="font-medium">{d[modeLabel[a.mode]]}</dd>
          </div>
        )}
        {a.years !== undefined && (
          <div>
            <dt className="text-xs text-muted-foreground">{d.experience}</dt>
            <dd className="font-medium">{fill(d.years, { n: a.years })}</dd>
          </div>
        )}
      </dl>
      <div className="border-t px-4 py-3">
        <h4 className="text-xs font-semibold text-muted-foreground">{d.documents}</h4>
        <ul className="mt-2 flex flex-col gap-1.5">
          {a.docs.map((doc) => (
            <li key={doc.key} className="flex items-center gap-2 text-sm">
              {doc.ok ? (
                <FileCheck className="size-4 shrink-0 text-success" aria-hidden />
              ) : (
                <FileX className="size-4 shrink-0 text-warning" aria-hidden />
              )}
              <span className="flex-1">{d[docLabel[doc.key]]}</span>
              {!doc.ok && <StatusBadge tone="warning">{d.missing}</StatusBadge>}
            </li>
          ))}
        </ul>
      </div>
      {!decision && (
        <div className="mt-auto flex flex-col gap-3 border-t px-4 py-3">
          {missing.length > 0 && <p className="text-xs text-warning">{d.missingHint}</p>}
          <div className="flex flex-wrap gap-2">
            <Button
              className="h-10 px-4"
              disabled={missing.length > 0}
              onClick={() => setDecision('approved')}
            >
              {common.approve}
            </Button>
            <Button variant="outline" className="h-10 px-4" onClick={() => setDecision('rejected')}>
              {common.reject}
            </Button>
          </div>
        </div>
      )}
    </article>
  );
}

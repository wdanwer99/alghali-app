import { Suspense } from 'react';
import { PaymentsBoard } from '@/components/admin/payments-queue';
import { PageHeader, PageSkeleton } from '@/components/admin/ui';
import type { Locale } from '@/i18n/config';
import { getDictionary, getLocale, type Dictionary } from '@/i18n/dictionaries';
import { requireAdmin } from '@/lib/auth';
import { loadPaymentQueue, loadRefunds } from '@/lib/data/commerce';

export default async function PaymentsPage() {
  const [d, locale] = await Promise.all([getDictionary(), getLocale()]);
  return (
    <>
      <PageHeader title={d.payments.title} description={d.payments.subtitle} />
      <Suspense fallback={<PageSkeleton stats={0} rows={5} />}>
        <Payments d={d} locale={locale} />
      </Suspense>
    </>
  );
}

async function Payments({ d, locale }: { d: Dictionary; locale: Locale }) {
  const { supabase } = await requireAdmin();
  const [receipts, refunds] = await Promise.all([
    loadPaymentQueue(supabase),
    loadRefunds(supabase),
  ]);
  return (
    <PaymentsBoard
      receipts={receipts}
      refunds={refunds}
      locale={locale}
      now={new Date().toISOString()}
      t={{ payments: d.payments, common: d.common, errors: d.errors }}
    />
  );
}

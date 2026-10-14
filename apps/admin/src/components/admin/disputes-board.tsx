'use client';

import { MessageSquareWarning, Send } from 'lucide-react';
import Link from 'next/link';
import { useState } from 'react';
import { Button } from '@/components/ui/button';
import type { Locale } from '@/i18n/config';
import type { Dictionary } from '@/i18n/dictionaries';
import { replyDispute, updateDispute } from '@/lib/actions/installation';
import type { Dispute } from '@/lib/data/installation';
import { cn } from '@/lib/utils';
import { formatRef } from '@/lib/format';
import { disputeTone, statusKey } from '@/lib/tones';
import { ConfirmDialog } from './interactive';
import { useAction } from './use-action';
import { EmptyState, Panel, StatusBadge } from './ui';

type Labels = {
  disputes: Dictionary['disputes'];
  common: Dictionary['common'];
  errors: Dictionary['errors'];
  status: Dictionary['status'];
};

/** Open ones first, then the newest. Times arrive pre-formatted from the server. */
export function DisputesBoard({
  disputes,
  locale,
  t,
}: {
  disputes: (Omit<Dispute, 'messages'> & {
    openedText: string;
    messages: (Dispute['messages'][number] & { atText: string })[];
  })[];
  locale: Locale;
  t: Labels;
}) {
  const d = t.disputes;
  const rank = { OPEN: 0, IN_REVIEW: 1, RESOLVED: 2, REJECTED: 2 } as const;
  const rows = [...disputes].sort(
    (a, b) => rank[a.status] - rank[b.status] || b.createdAt.localeCompare(a.createdAt),
  );
  const [selected, setSelected] = useState<string | null>(rows[0]?.id ?? null);
  const [reply, setReply] = useState('');
  const [deciding, setDeciding] = useState<'RESOLVED' | 'REJECTED' | null>(null);
  const { pending, run } = useAction(t.errors);
  const current = rows.find((x) => x.id === selected) ?? null;
  const closed = current ? current.status === 'RESOLVED' || current.status === 'REJECTED' : true;

  if (rows.length === 0) {
    return (
      <Panel>
        <EmptyState icon={<MessageSquareWarning />} title={d.empty} body={d.emptyBody} />
      </Panel>
    );
  }

  return (
    <div className="grid grid-cols-1 items-start gap-6 lg:grid-cols-[22rem_minmax(0,1fr)]">
      <Panel>
        <ul className="divide-y">
          {rows.map((x) => (
            <li key={x.id}>
              <button
                type="button"
                onClick={() => setSelected(x.id)}
                aria-current={x.id === selected}
                className={cn(
                  'flex w-full flex-col gap-1 px-4 py-3 text-start transition-colors hover:bg-muted/60 focus-visible:bg-muted focus-visible:outline-none',
                  x.id === selected && 'bg-muted',
                )}
              >
                <span className="flex items-center justify-between gap-2">
                  <span className="text-sm font-semibold">{d.categories[x.category]}</span>
                  <StatusBadge tone={disputeTone[x.status]}>
                    {t.status.dispute[statusKey(x.status)]}
                  </StatusBadge>
                </span>
                <span className="text-xs text-muted-foreground">
                  <bdi>{x.openedBy}</bdi> · {d.roles[x.openerRole]}
                  {x.ref && <> · {formatRef(x.ref)}</>} · {x.openedText}
                </span>
              </button>
            </li>
          ))}
        </ul>
      </Panel>

      {current ? (
        <Panel
          title={d.categories[current.category]}
          actions={
            <StatusBadge tone={disputeTone[current.status]}>
              {t.status.dispute[statusKey(current.status)]}
            </StatusBadge>
          }
        >
          <div className="flex flex-col gap-4 p-4">
            <div className="text-sm">
              <p className="text-xs text-muted-foreground">
                <bdi>{current.openedBy}</bdi> · {d.roles[current.openerRole]} · {current.openedText}
              </p>
              <p className="mt-2 whitespace-pre-wrap">{current.description}</p>
              <div className="mt-2 flex flex-wrap gap-3 text-sm">
                {current.orderId && (
                  <Link
                    href={`/${locale}/orders/${current.orderId}`}
                    className="underline-offset-2 hover:underline"
                  >
                    {d.openOrder}
                  </Link>
                )}
                {current.bookingId && (
                  <Link
                    href={`/${locale}/bookings/${current.bookingId}`}
                    className="underline-offset-2 hover:underline"
                  >
                    {d.openBooking}
                  </Link>
                )}
              </div>
            </div>

            <div>
              <h3 className="mb-2 text-xs font-semibold text-muted-foreground">{d.messages}</h3>
              {current.messages.length === 0 ? (
                <p className="text-sm text-muted-foreground">{d.noMessages}</p>
              ) : (
                <ol className="flex flex-col gap-2">
                  {current.messages.map((m) => (
                    <li
                      key={m.id}
                      className={cn(
                        'max-w-[85%] rounded-lg px-3 py-2 text-sm',
                        m.fromAdmin ? 'self-end bg-primary/10' : 'self-start bg-muted',
                      )}
                    >
                      <div className="text-xs text-muted-foreground">
                        {m.fromAdmin ? d.admin : <bdi>{m.sender}</bdi>} · {m.atText}
                      </div>
                      <p className="whitespace-pre-wrap">{m.body}</p>
                    </li>
                  ))}
                </ol>
              )}
            </div>

            {current.resolution && (
              <p className="rounded-lg bg-muted px-3 py-2 text-sm">
                <span className="font-semibold">{d.closed}: </span>
                {current.resolution}
              </p>
            )}

            {!closed && (
              <form
                className="flex flex-col gap-3 border-t pt-4"
                onSubmit={(e) => {
                  e.preventDefault();
                  const text = reply.trim();
                  if (!text) return;
                  run(() => replyDispute(current.id, text), {
                    success: d.sentToast,
                    onDone: () => setReply(''),
                  });
                }}
              >
                <textarea
                  value={reply}
                  onChange={(e) => setReply(e.target.value)}
                  rows={3}
                  maxLength={2000}
                  placeholder={d.replyPlaceholder}
                  aria-label={d.replyPlaceholder}
                  className="w-full rounded-lg border border-input bg-card px-3 py-2 text-sm outline-none placeholder:text-muted-foreground focus-visible:border-ring focus-visible:ring-2 focus-visible:ring-ring/30"
                />
                <div className="flex flex-wrap gap-2">
                  <Button type="submit" className="h-10 px-4" disabled={pending || !reply.trim()}>
                    <Send />
                    {d.reply}
                  </Button>
                  {current.status === 'OPEN' && (
                    <Button
                      type="button"
                      variant="outline"
                      className="h-10 px-4"
                      disabled={pending}
                      onClick={() =>
                        run(() => updateDispute(current.id, 'IN_REVIEW'), { success: d.takenToast })
                      }
                    >
                      {d.take}
                    </Button>
                  )}
                  <Button
                    type="button"
                    variant="outline"
                    className="h-10 px-4"
                    disabled={pending}
                    onClick={() => setDeciding('RESOLVED')}
                  >
                    {d.resolve}
                  </Button>
                  <Button
                    type="button"
                    variant="outline"
                    className="h-10 px-4"
                    disabled={pending}
                    onClick={() => setDeciding('REJECTED')}
                  >
                    {d.reject}
                  </Button>
                </div>
              </form>
            )}
          </div>
        </Panel>
      ) : (
        <Panel>
          <p className="px-4 py-12 text-center text-sm text-muted-foreground">{d.pick}</p>
        </Panel>
      )}

      <ConfirmDialog
        open={deciding !== null}
        onOpenChange={(o) => !o && setDeciding(null)}
        title={d.decisionTitle}
        description={d.decisionBody}
        reasonLabel={d.decision}
        reasonPlaceholder={d.decisionPlaceholder}
        confirmLabel={deciding === 'REJECTED' ? d.reject : d.resolve}
        cancelLabel={t.common.cancel}
        tone={deciding === 'REJECTED' ? 'danger' : undefined}
        pending={pending}
        onConfirm={(text) => {
          const status = deciding;
          setDeciding(null);
          if (current && status)
            run(() => updateDispute(current.id, status, text), { success: d.resolvedToast });
        }}
      />
    </div>
  );
}

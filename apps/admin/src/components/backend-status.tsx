import { connection } from 'next/server';
import { StatusBadge } from '@/components/admin/ui';
import type { Locale } from '@/i18n/config';
import type { Dictionary } from '@/i18n/dictionaries';
import { dateTime } from '@/lib/format';
import { getAnonClient } from '@/lib/supabase/server';

type Labels = Dictionary['system'];

/** Calls the `ping()` RPC so we can see at a glance whether the backend is reachable. */
export async function BackendStatus({ labels, locale }: { labels: Labels; locale: Locale }) {
  await connection(); // always check live, never bake the result into the static shell
  const supabase = getAnonClient();
  if (!supabase) {
    return <p className="text-sm text-muted-foreground">{labels.backendNotConfigured}</p>;
  }

  const { data, error } = await supabase.rpc('ping');
  if (error || data === null || typeof data !== 'object' || Array.isArray(data)) {
    return <StatusBadge tone="danger">{labels.backendError}</StatusBadge>;
  }

  const serverTime = typeof data.server_time === 'string' ? new Date(data.server_time) : null;
  return (
    <div className="flex flex-wrap items-center gap-3">
      <StatusBadge tone="success">{labels.backendOk}</StatusBadge>
      {serverTime && (
        <span className="text-sm text-muted-foreground">
          {labels.serverTime}: {dateTime(serverTime, locale)}
        </span>
      )}
    </div>
  );
}

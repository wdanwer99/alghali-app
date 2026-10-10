import { connection } from 'next/server';
import { Badge } from '@/components/ui/badge';
import type { Dictionary } from '@/i18n/dictionaries';
import { getAnonClient } from '@/lib/supabase/server';

type Labels = Dictionary['home'];

/** Calls the `ping()` RPC so we can see at a glance whether the backend is reachable. */
export async function BackendStatus({ labels, locale }: { labels: Labels; locale: string }) {
  await connection(); // always check live, never bake the result into the static shell
  const supabase = getAnonClient();
  if (!supabase) {
    return <Badge variant="outline">{labels.backendNotConfigured}</Badge>;
  }

  const { data, error } = await supabase.rpc('ping');
  if (error || data === null || typeof data !== 'object' || Array.isArray(data)) {
    return <Badge variant="destructive">{labels.backendError}</Badge>;
  }

  const serverTime = typeof data.server_time === 'string' ? new Date(data.server_time) : null;
  return (
    <div className="flex flex-wrap items-center gap-3">
      <Badge>{labels.backendOk}</Badge>
      {serverTime && (
        <span className="text-sm text-muted-foreground">
          {labels.serverTime}:{' '}
          {serverTime.toLocaleString(locale === 'ar' ? 'ar-SD' : 'en-GB', {
            timeZone: 'Africa/Khartoum',
          })}
        </span>
      )}
    </div>
  );
}

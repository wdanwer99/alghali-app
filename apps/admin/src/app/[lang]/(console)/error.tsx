'use client';

import { RotateCw, ServerCrash } from 'lucide-react';
import { useParams } from 'next/navigation';
import { useEffect } from 'react';
import { Button } from '@/components/ui/button';
import ar from '@/i18n/dictionaries/ar.json';
import en from '@/i18n/dictionaries/en.json';

/** A query failed (network, database): say so plainly and offer a retry. */
export default function ConsoleError({
  error,
  retry,
}: {
  error: Error & { digest?: string };
  retry: () => void;
}) {
  const { lang } = useParams<{ lang: string }>();
  const t = (lang === 'en' ? en : ar).common;
  useEffect(() => {
    console.error(error);
  }, [error]);
  return (
    <div className="rise flex flex-col items-center gap-4 rounded-xl bg-card px-6 py-16 text-center ring-1 ring-foreground/10">
      <span className="grid size-12 place-items-center rounded-2xl bg-danger-soft text-destructive">
        <ServerCrash className="size-6" />
      </span>
      <div>
        <h1 className="text-lg font-semibold">{t.errorTitle}</h1>
        <p className="mx-auto mt-1 max-w-md text-sm text-muted-foreground">{t.errorBody}</p>
      </div>
      <Button variant="outline" className="h-10 px-4" onClick={() => retry()}>
        <RotateCw />
        {t.retry}
      </Button>
    </div>
  );
}

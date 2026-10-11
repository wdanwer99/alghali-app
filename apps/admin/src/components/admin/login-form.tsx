'use client';

import { useRouter } from 'next/navigation';
import { useState } from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import type { Locale } from '@/i18n/config';
import type { Dictionary } from '@/i18n/dictionaries';

/** Demo sign-in: any email and password opens the console (Supabase Auth replaces this in M1). */
export function LoginForm({ locale, d }: { locale: Locale; d: Dictionary['login'] }) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        setBusy(true);
        router.push(`/${locale}`);
      }}
      className="flex flex-col gap-4"
    >
      <div className="flex flex-col gap-2">
        <Label htmlFor="email">{d.email}</Label>
        <Input
          id="email"
          name="email"
          type="email"
          autoComplete="username"
          dir="ltr"
          required
          className="h-10"
        />
      </div>
      <div className="flex flex-col gap-2">
        <Label htmlFor="password">{d.password}</Label>
        <Input
          id="password"
          name="password"
          type="password"
          autoComplete="current-password"
          dir="ltr"
          required
          className="h-10"
        />
      </div>
      <Button type="submit" className="h-10" disabled={busy}>
        {d.submit}
      </Button>
      <p className="text-xs text-muted-foreground">{d.demoHint}</p>
    </form>
  );
}

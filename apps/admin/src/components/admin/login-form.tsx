'use client';

import { CircleAlert, Eye, EyeOff, Loader2 } from 'lucide-react';
import { AnimatePresence, motion, useAnimate } from 'motion/react';
import { useActionState, useEffect, useState, type ReactNode } from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import type { Locale } from '@/i18n/config';
import type { Dictionary } from '@/i18n/dictionaries';
import { signIn, type SignInState } from '@/lib/actions/auth';

/** A quiet note above the form, e.g. "Please sign in to continue". */
export function LoginNotice({ text }: { text: string }) {
  return (
    <motion.p
      role="status"
      initial={{ opacity: 0, height: 0 }}
      animate={{ opacity: 1, height: 'auto' }}
      className="overflow-hidden"
    >
      <span className="flex items-start gap-2 rounded-lg bg-muted px-3 py-2.5 text-sm text-muted-foreground">
        <CircleAlert className="mt-0.5 size-4 shrink-0" aria-hidden />
        {text}
      </span>
    </motion.p>
  );
}

/**
 * Email + password sign-in against Supabase Auth; only admins get in. [notice] may stream
 * in later (it reads the address); the form itself is never replaced, so nothing typed is lost.
 */
export function LoginForm({
  locale,
  d,
  notice,
}: {
  locale: Locale;
  d: Dictionary['login'];
  notice?: ReactNode;
}) {
  const [state, action, pending] = useActionState<SignInState, FormData>(signIn, {});
  const [showPassword, setShowPassword] = useState(false);
  const [scope, animate] = useAnimate();

  // A small shake when the attempt fails, so the error is noticed without reading.
  useEffect(() => {
    if (state.error && scope.current) {
      animate(scope.current, { x: [0, -8, 8, -5, 5, 0] }, { duration: 0.4 });
    }
  }, [state, animate, scope]);

  const message = state.error ? d[state.error] : null;
  return (
    <form ref={scope} action={action} className="flex flex-col gap-4">
      <input type="hidden" name="locale" value={locale} />
      {!state.error && notice}
      <AnimatePresence initial={false}>
        {message && (
          <motion.p
            key={message}
            role="alert"
            initial={{ opacity: 0, height: 0 }}
            animate={{ opacity: 1, height: 'auto' }}
            exit={{ opacity: 0, height: 0 }}
            className="overflow-hidden"
          >
            <span className="flex items-start gap-2 rounded-lg bg-danger-soft px-3 py-2.5 text-sm text-destructive">
              <CircleAlert className="mt-0.5 size-4 shrink-0" aria-hidden />
              {message}
            </span>
          </motion.p>
        )}
      </AnimatePresence>
      <div className="flex flex-col gap-2">
        <Label htmlFor="email">{d.email}</Label>
        <Input
          id="email"
          name="email"
          type="email"
          autoComplete="username"
          dir="ltr"
          required
          defaultValue={state.email}
          aria-invalid={state.error === 'invalidCredentials' || undefined}
          className="h-11"
        />
      </div>
      <div className="flex flex-col gap-2">
        <Label htmlFor="password">{d.password}</Label>
        <div className="relative">
          <Input
            id="password"
            name="password"
            type={showPassword ? 'text' : 'password'}
            autoComplete="current-password"
            dir="ltr"
            required
            aria-invalid={state.error === 'invalidCredentials' || undefined}
            className="h-11 pe-11"
          />
          <button
            type="button"
            onClick={() => setShowPassword((v) => !v)}
            aria-label={showPassword ? d.hidePassword : d.showPassword}
            aria-pressed={showPassword}
            className="absolute inset-y-0 end-0 grid w-11 cursor-pointer place-items-center rounded-e-lg text-muted-foreground transition-colors hover:text-foreground focus-visible:ring-2 focus-visible:ring-ring focus-visible:outline-none"
          >
            {showPassword ? <EyeOff className="size-4" /> : <Eye className="size-4" />}
          </button>
        </div>
      </div>
      <Button type="submit" className="h-11 text-base" disabled={pending}>
        {pending && <Loader2 className="animate-spin" aria-hidden />}
        {pending ? d.signingIn : d.submit}
      </Button>
    </form>
  );
}

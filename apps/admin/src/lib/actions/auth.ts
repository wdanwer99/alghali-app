'use server';

import { redirect } from 'next/navigation';
import { isLocale } from '@/i18n/config';
import { getSessionClient } from '@/lib/supabase/server';

export type SignInError =
  'invalidCredentials' | 'notAdmin' | 'rateLimited' | 'notConfigured' | 'failed';
export type SignInState = { error?: SignInError; email?: string };

/** Email + password sign-in; only accounts with the ADMIN role may stay signed in. */
export async function signIn(_prev: SignInState, form: FormData): Promise<SignInState> {
  const email = String(form.get('email') ?? '').trim();
  const password = String(form.get('password') ?? '');
  const lang = String(form.get('locale') ?? '');
  const supabase = await getSessionClient();
  if (!supabase) return { error: 'notConfigured', email };

  const { error } = await supabase.auth.signInWithPassword({ email, password });
  if (error) {
    if (error.code === 'invalid_credentials') return { error: 'invalidCredentials', email };
    if (error.status === 429) return { error: 'rateLimited', email };
    return { error: 'failed', email };
  }
  const { data: isAdmin } = await supabase.rpc('is_admin');
  if (!isAdmin) {
    await supabase.auth.signOut();
    return { error: 'notAdmin', email };
  }
  redirect(isLocale(lang) ? `/${lang}` : '/');
}

export async function signOut(form: FormData) {
  const lang = String(form.get('locale') ?? '');
  const supabase = await getSessionClient();
  await supabase?.auth.signOut();
  redirect(isLocale(lang) ? `/${lang}/login` : '/login');
}

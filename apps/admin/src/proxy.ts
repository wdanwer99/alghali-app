import { NextResponse, type NextRequest } from 'next/server';
import { defaultLocale, isLocale, LOCALE_COOKIE, locales, type Locale } from '@/i18n/config';
import { refreshSession } from '@/lib/supabase/proxy';

/**
 * 1. Sends any path without a locale prefix to the saved language, or Arabic.
 * 2. Keeps the Supabase session fresh and sends signed-out visitors to sign-in, except on
 *    the sign-in and app download pages (pages and actions still check the admin role).
 */
export async function proxy(request: NextRequest) {
  const { pathname } = request.nextUrl;
  const locale = locales.find((l) => pathname === `/${l}` || pathname.startsWith(`/${l}/`));
  if (!locale) {
    const saved = request.cookies.get(LOCALE_COOKIE)?.value;
    const target = isLocale(saved) ? saved : defaultLocale;
    const url = request.nextUrl.clone();
    url.pathname = `/${target}${pathname === '/' ? '' : pathname}`;
    return NextResponse.redirect(url);
  }

  const response = NextResponse.next({ request });
  const { configured, signedIn } = await refreshSession(request, response);
  // The sign-in page itself sends a signed-in admin on (a signed-in non-admin stays there).
  // The app download page is public (D-058).
  const open = [`/${locale}/login`, `/${locale}/download`];
  if (configured && !signedIn && !open.includes(pathname)) {
    return toLogin(request, response, locale);
  }
  return response;
}

function toLogin(request: NextRequest, from: NextResponse, locale: Locale) {
  const url = request.nextUrl.clone();
  url.pathname = `/${locale}/login`;
  url.search = '';
  const response = NextResponse.redirect(url);
  // Keep any cookie changes the refresh made (e.g. clearing an expired session).
  for (const cookie of from.cookies.getAll()) response.cookies.set(cookie);
  return response;
}

export const config = {
  matcher: ['/((?!_next|api|favicon.ico|.*\\..*).*)'],
};

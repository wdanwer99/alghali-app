/**
 * The session cookies are for the server only: the browser never talks to Supabase, so page
 * scripts can't read them (M7 security review). Used by the proxy and the server client.
 */
export const SESSION_COOKIE = { httpOnly: true, sameSite: 'lax' } as const;

'use client';

import {
  Check,
  Copy,
  KeyRound,
  Loader2,
  Search,
  ShieldCheck,
  ShieldOff,
  Sparkles,
  Users,
} from 'lucide-react';
import { AnimatePresence, motion } from 'motion/react';
import { useId, useRef, useState, useTransition } from 'react';
import { cn } from 'cn';
import { Button } from '@/components/ui/button';
import type { Dictionary } from '@/i18n/dictionaries';
import { findUsers, setAdminRole, setTemporaryPassword } from '@/lib/actions/users';
import type { Role, UserRow } from '@/lib/data/users';
import { ago, digits, fill } from '@/lib/format';
import { strongEnough, temporaryPassword } from '@/lib/password';
import { ConfirmDialog, Modal } from './interactive';
import { phoneText } from './shop-facts';
import { useAction } from './use-action';
import { EmptyState, Panel, Table, Td, Th } from './ui';

type Labels = {
  u: Dictionary['users'];
  common: Dictionary['common'];
  errors: Dictionary['errors'];
};

const roleOrder: Role[] = ['ADMIN', 'SHOP_OWNER', 'SHOP_STAFF', 'TECHNICIAN', 'BUYER'];

export function UsersBoard({
  initial,
  meId,
  now,
  limit,
  t,
}: {
  initial: UserRow[];
  meId: string;
  /** The server's clock, so "joined 3 d ago" reads the same before and after hydration. */
  now: string;
  limit: number;
  t: Labels;
}) {
  const { u } = t;
  const [query, setQuery] = useState('');
  const [rows, setRows] = useState(initial);
  const [searching, startSearch] = useTransition();
  const [confirm, setConfirm] = useState<{ user: UserRow; admin: boolean } | null>(null);
  const [passwordFor, setPasswordFor] = useState<UserRow | null>(null);
  const { pending, run } = useAction(t.errors);
  const latest = useRef(0);
  const nowDate = new Date(now);

  // Searches as you type, 300 ms after the last key; older answers are ignored.
  const search = (q: string) => {
    const ticket = ++latest.current;
    startSearch(async () => {
      const found = await findUsers(q);
      if (ticket === latest.current) setRows(found);
    });
  };
  const timer = useRef<ReturnType<typeof setTimeout>>(undefined);
  const onQuery = (q: string) => {
    setQuery(q);
    clearTimeout(timer.current);
    timer.current = setTimeout(() => search(q), q ? 300 : 0);
  };

  const label = (x: UserRow) => x.name || x.email || u.noName;

  return (
    <>
      <div className="flex flex-wrap items-center justify-between gap-3">
        <label className="relative block w-full sm:w-80">
          <span className="sr-only">{t.common.search}</span>
          <Search className="pointer-events-none absolute start-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
          <input
            type="search"
            value={query}
            onChange={(e) => onQuery(e.target.value)}
            placeholder={u.searchPlaceholder}
            className="h-10 w-full rounded-lg border border-input bg-card ps-9 pe-9 text-base outline-none focus-visible:border-ring focus-visible:ring-2 focus-visible:ring-ring/30"
          />
          {searching && (
            <Loader2 className="absolute end-3 top-1/2 size-4 -translate-y-1/2 animate-spin text-muted-foreground" />
          )}
        </label>
        <span className="text-sm text-muted-foreground" aria-live="polite">
          {!query && rows.length >= limit
            ? fill(u.countLimit, { n: digits(rows.length) })
            : fill(u.count, { n: digits(rows.length) })}
        </span>
      </div>

      <Panel>
        {rows.length === 0 ? (
          <EmptyState icon={<Users />} title={u.empty} body={u.emptyBody} />
        ) : (
          <Table className={cn('transition-opacity', searching && 'opacity-60')}>
            <thead>
              <tr>
                <Th>{u.name}</Th>
                <Th className="hidden md:table-cell">{t.common.phone}</Th>
                <Th>{u.roles}</Th>
                <Th className="hidden sm:table-cell">{u.joined}</Th>
                <Th className="text-end">
                  <span className="sr-only">{t.common.details}</span>
                </Th>
              </tr>
            </thead>
            <tbody>
              <AnimatePresence initial={false}>
                {rows.map((x) => {
                  const isAdmin = x.roles.includes('ADMIN');
                  const self = x.id === meId;
                  return (
                    <motion.tr
                      key={x.id}
                      layout="position"
                      initial={{ opacity: 0 }}
                      animate={{ opacity: 1 }}
                      exit={{ opacity: 0 }}
                      transition={{ duration: 0.18 }}
                      className="transition-colors hover:bg-muted/40"
                    >
                      <Td className="max-w-72 whitespace-normal">
                        <div className="flex items-center gap-3">
                          <span
                            className={cn(
                              'grid size-9 shrink-0 place-items-center rounded-full text-sm font-bold uppercase',
                              isAdmin ? 'bg-foreground text-background' : 'bg-muted',
                            )}
                          >
                            {label(x).slice(0, 1)}
                          </span>
                          <div className="min-w-0">
                            <div className="flex items-center gap-2 font-medium">
                              <span className="truncate">{label(x)}</span>
                              {self && (
                                <span className="rounded bg-info-soft px-1.5 text-[11px] font-semibold text-info">
                                  {u.you}
                                </span>
                              )}
                            </div>
                            <div className="truncate text-xs text-muted-foreground" dir="ltr">
                              {x.email}
                            </div>
                          </div>
                        </div>
                      </Td>
                      <Td className="hidden md:table-cell">
                        {x.phone ? <span className="text-sm">{phoneText(x.phone)}</span> : '—'}
                      </Td>
                      <Td className="whitespace-normal">
                        <span className="flex flex-wrap gap-1">
                          {[...x.roles]
                            .sort((a, b) => roleOrder.indexOf(a) - roleOrder.indexOf(b))
                            .map((r) => (
                              <span
                                key={r}
                                className={cn(
                                  'rounded-md px-1.5 py-0.5 text-xs font-semibold',
                                  r === 'ADMIN'
                                    ? 'bg-foreground text-background'
                                    : 'bg-muted text-muted-foreground',
                                )}
                              >
                                {u.role[r]}
                              </span>
                            ))}
                        </span>
                      </Td>
                      <Td className="hidden text-sm text-muted-foreground sm:table-cell">
                        {ago(new Date(x.createdAt), nowDate, t.common)}
                      </Td>
                      <Td className="text-end">
                        <span className="inline-flex gap-1.5">
                          <Button
                            variant="outline"
                            className="h-8 px-2.5"
                            disabled={pending}
                            onClick={() => setPasswordFor(x)}
                          >
                            <KeyRound />
                            <span className="hidden lg:inline">{u.setPassword}</span>
                          </Button>
                          <Button
                            variant="outline"
                            className="h-8 px-2.5"
                            disabled={pending || (self && isAdmin)}
                            title={self && isAdmin ? t.errors.CANNOT_REVOKE_OWN_ADMIN : undefined}
                            onClick={() => setConfirm({ user: x, admin: !isAdmin })}
                          >
                            {isAdmin ? <ShieldOff /> : <ShieldCheck />}
                            <span className="hidden lg:inline">
                              {isAdmin ? u.removeAdmin : u.makeAdmin}
                            </span>
                          </Button>
                        </span>
                      </Td>
                    </motion.tr>
                  );
                })}
              </AnimatePresence>
            </tbody>
          </Table>
        )}
      </Panel>

      <ConfirmDialog
        open={confirm !== null}
        onOpenChange={(o) => !o && setConfirm(null)}
        title={
          confirm
            ? fill(confirm.admin ? u.makeAdminTitle : u.removeAdminTitle, {
                name: label(confirm.user),
              })
            : ''
        }
        description={confirm?.admin ? u.makeAdminBody : u.removeAdminBody}
        confirmLabel={confirm?.admin ? u.makeAdmin : u.removeAdmin}
        cancelLabel={t.common.cancel}
        tone={confirm?.admin ? 'default' : 'danger'}
        pending={pending}
        onConfirm={() => {
          if (!confirm) return;
          const { user, admin } = confirm;
          setConfirm(null);
          run(() => setAdminRole(user.id, admin), {
            success: fill(admin ? u.madeAdmin : u.removedAdmin, { name: label(user) }),
            onDone: () => search(query),
          });
        }}
      />

      <PasswordDialog
        user={passwordFor}
        name={passwordFor ? label(passwordFor) : ''}
        t={t}
        onClose={() => setPasswordFor(null)}
      />
    </>
  );
}

function PasswordDialog({
  user,
  name,
  t,
  onClose,
}: {
  user: UserRow | null;
  name: string;
  t: Labels;
  onClose: () => void;
}) {
  // Keep the last user while the dialog animates closed, so its content doesn't blank out.
  const [last, setLast] = useState(user);
  if (user && user !== last) setLast(user);
  const shown = user ?? last;
  return (
    <Modal
      open={user !== null}
      onOpenChange={(o) => !o && onClose()}
      title={fill(t.u.setPasswordTitle, { name: name || (shown?.name ?? '') })}
      description={t.u.setPasswordBody}
    >
      {/* Keyed per user: every opening starts with a freshly made password. */}
      {shown && <PasswordForm key={shown.id} user={shown} name={name} t={t} onDone={onClose} />}
    </Modal>
  );
}

function PasswordForm({
  user,
  name,
  t,
  onDone,
}: {
  user: UserRow;
  name: string;
  t: Labels;
  onDone: () => void;
}) {
  const { u } = t;
  const [password, setPassword] = useState(temporaryPassword);
  const [copied, setCopied] = useState(false);
  const { pending, run } = useAction(t.errors);
  const id = useId();
  const ok = strongEnough(password);
  const close = onDone;

  return (
    <>
      <form
        className="flex flex-col gap-4"
        onSubmit={(e) => {
          e.preventDefault();
          if (!ok) return;
          run(() => setTemporaryPassword(user.id, password), {
            success: fill(u.passwordSet, { name }),
            onDone: close,
          });
        }}
      >
        <div className="flex flex-col gap-1.5">
          <label htmlFor={id} className="text-sm font-medium">
            {u.newPassword}
          </label>
          <div className="flex gap-2">
            <input
              id={id}
              dir="ltr"
              autoComplete="off"
              spellCheck={false}
              value={password}
              onChange={(e) => {
                setPassword(e.target.value);
                setCopied(false);
              }}
              aria-invalid={(password.length > 0 && !ok) || undefined}
              className="h-11 min-w-0 flex-1 rounded-lg border border-input bg-card px-3 font-mono text-lg tracking-wider outline-none focus-visible:border-ring focus-visible:ring-2 focus-visible:ring-ring/30 aria-invalid:border-destructive"
            />
            <Button
              type="button"
              variant="outline"
              className="h-11 px-3"
              onClick={() => {
                setPassword(temporaryPassword());
                setCopied(false);
              }}
            >
              <Sparkles />
              {u.generate}
            </Button>
          </div>
          <p
            className={cn(
              'text-xs',
              ok || !password ? 'text-muted-foreground' : 'text-destructive',
            )}
          >
            {u.passwordRule}
          </p>
        </div>
        <div className="flex flex-wrap items-center justify-between gap-2">
          <Button
            type="button"
            variant="ghost"
            className="h-10 px-3"
            disabled={!password}
            onClick={async () => {
              try {
                await navigator.clipboard.writeText(password);
                setCopied(true);
              } catch {
                setCopied(false);
              }
            }}
          >
            <AnimatePresence mode="wait" initial={false}>
              <motion.span
                key={copied ? 'done' : 'copy'}
                initial={{ opacity: 0, scale: 0.8 }}
                animate={{ opacity: 1, scale: 1 }}
                exit={{ opacity: 0, scale: 0.8 }}
                className="inline-flex items-center gap-1.5"
              >
                {copied ? <Check className="size-4 text-success" /> : <Copy className="size-4" />}
                {copied ? u.copied : u.copy}
              </motion.span>
            </AnimatePresence>
          </Button>
          <div className="flex gap-2">
            <Button type="button" variant="outline" className="h-10 px-4" onClick={close}>
              {t.common.cancel}
            </Button>
            <Button type="submit" className="h-10 px-4" disabled={!ok || pending}>
              {pending ? <Loader2 className="animate-spin" /> : <KeyRound />}
              {u.save}
            </Button>
          </div>
        </div>
      </form>
    </>
  );
}

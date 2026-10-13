'use client';

import { Dialog } from '@base-ui/react/dialog';
import { CornerDownLeft, Languages, LogOut, Search } from 'lucide-react';
import { motion } from 'motion/react';
import { usePathname, useRouter } from 'next/navigation';
import {
  useEffect,
  useId,
  useMemo,
  useRef,
  useState,
  useTransition,
  type ComponentType,
} from 'react';
import { cn } from 'cn';
import { LOCALE_COOKIE, type Locale } from '@/i18n/config';
import type { Dictionary } from '@/i18n/dictionaries';
import { signOut } from '@/lib/actions/auth';
import { searchKey } from '@/lib/format';
import type { NavItem } from './nav';
import { SampleTag } from './ui';

type Entry = {
  id: string;
  label: string;
  group: string;
  icon: ComponentType<{ className?: string }>;
  sample?: boolean;
  run: () => void;
};

/**
 * Ctrl/⌘ K: type to jump to any page or run a common action. Arrow keys move,
 * Enter opens, Escape closes. Matching ignores Arabic letter variants.
 */
export function CommandPalette({
  open,
  onOpenChange,
  locale,
  d,
  sampleTag,
  groups,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  locale: Locale;
  d: Dictionary['nav'];
  sampleTag: string;
  groups: { title: string | null; items: NavItem[] }[];
}) {
  const router = useRouter();
  const pathname = usePathname();
  const [query, setQuery] = useState('');
  const [active, setActive] = useState(0);
  const [, startTransition] = useTransition();
  const listRef = useRef<HTMLDivElement>(null);
  const listId = useId();

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault();
        onOpenChange(!open);
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [open, onOpenChange]);

  const entries = useMemo<Entry[]>(() => {
    const close = () => onOpenChange(false);
    const target: Locale = locale === 'ar' ? 'en' : 'ar';
    const pages = groups.flatMap((g) =>
      g.items.map((item) => ({
        id: item.href,
        label: item.label,
        group: d.commandPages,
        icon: item.icon,
        sample: item.sample,
        run: () => {
          close();
          router.push(item.href);
        },
      })),
    );
    const actions: Entry[] = [
      {
        id: 'lang',
        label: d.switchLanguage,
        group: d.commandActions,
        icon: Languages,
        run: () => {
          close();
          document.cookie = `${LOCALE_COOKIE}=${target}; path=/; max-age=31536000; samesite=lax`;
          router.push(pathname.replace(/^\/(ar|en)(?=\/|$)/, `/${target}`));
        },
      },
      {
        id: 'signout',
        label: d.signOut,
        group: d.commandActions,
        icon: LogOut,
        run: () => {
          close();
          const form = new FormData();
          form.set('locale', locale);
          startTransition(() => signOut(form));
        },
      },
    ];
    return [...pages, ...actions];
  }, [groups, d, locale, pathname, router, onOpenChange]);

  const q = searchKey(query);
  const shown = q ? entries.filter((e) => searchKey(e.label).includes(q)) : entries;
  const current = Math.min(active, Math.max(0, shown.length - 1));

  useEffect(() => {
    listRef.current
      ?.querySelector(`[data-index="${current}"]`)
      ?.scrollIntoView({ block: 'nearest' });
  }, [current]);

  return (
    <Dialog.Root
      open={open}
      onOpenChange={(next) => {
        onOpenChange(next);
        if (!next) {
          setQuery('');
          setActive(0);
        }
      }}
    >
      <Dialog.Portal>
        <Dialog.Backdrop className="fixed inset-0 z-50 bg-black/40 backdrop-blur-[2px] transition-opacity duration-200 data-ending-style:opacity-0 data-starting-style:opacity-0" />
        <Dialog.Popup className="fixed top-[12vh] left-1/2 z-50 flex max-h-[70vh] w-[34rem] max-w-[calc(100vw-2rem)] -translate-x-1/2 flex-col overflow-hidden rounded-2xl bg-popover text-popover-foreground shadow-2xl ring-1 ring-foreground/10 transition-[scale,opacity,translate] duration-200 ease-out-soft data-ending-style:-translate-y-2 data-ending-style:scale-[0.98] data-ending-style:opacity-0 data-starting-style:-translate-y-2 data-starting-style:scale-[0.98] data-starting-style:opacity-0">
          <Dialog.Title className="sr-only">{d.jumpTo}</Dialog.Title>
          <div className="flex items-center gap-3 border-b px-4">
            <Search className="size-4.5 shrink-0 text-muted-foreground" aria-hidden />
            <input
              autoFocus
              value={query}
              onChange={(e) => {
                setQuery(e.target.value);
                setActive(0);
              }}
              onKeyDown={(e) => {
                if (e.key === 'ArrowDown') {
                  e.preventDefault();
                  setActive((i) =>
                    shown.length ? (Math.min(i, shown.length - 1) + 1) % shown.length : 0,
                  );
                } else if (e.key === 'ArrowUp') {
                  e.preventDefault();
                  setActive((i) =>
                    shown.length
                      ? (Math.min(i, shown.length - 1) - 1 + shown.length) % shown.length
                      : 0,
                  );
                } else if (e.key === 'Enter') {
                  e.preventDefault();
                  shown[current]?.run();
                }
              }}
              placeholder={d.commandPlaceholder}
              role="combobox"
              aria-expanded
              aria-controls={listId}
              aria-activedescendant={shown[current] ? `${listId}-${current}` : undefined}
              className="h-14 flex-1 bg-transparent text-base outline-none placeholder:text-muted-foreground"
            />
          </div>
          <div ref={listRef} id={listId} role="listbox" className="overflow-y-auto p-2">
            {shown.length === 0 && (
              <p className="px-3 py-10 text-center text-sm text-muted-foreground">
                {d.commandEmpty}
              </p>
            )}
            {shown.map((e, i) => {
              const Icon = e.icon;
              const firstOfGroup = i === 0 || shown[i - 1].group !== e.group;
              return (
                <div key={e.id}>
                  {firstOfGroup && (
                    <div className="px-3 pt-2 pb-1 text-xs font-semibold text-muted-foreground">
                      {e.group}
                    </div>
                  )}
                  <div
                    id={`${listId}-${i}`}
                    data-index={i}
                    role="option"
                    aria-selected={i === current}
                    onMouseMove={() => setActive(i)}
                    onClick={() => e.run()}
                    className={cn(
                      'relative flex h-11 cursor-pointer items-center gap-3 rounded-lg px-3 text-sm',
                      i === current ? 'text-foreground' : 'text-foreground/80',
                    )}
                  >
                    {i === current && (
                      <motion.span
                        layoutId="palette-active"
                        className="absolute inset-0 rounded-lg bg-muted"
                        transition={{ type: 'spring', stiffness: 700, damping: 45 }}
                      />
                    )}
                    <Icon className="relative size-4.5 shrink-0 text-muted-foreground" />
                    <span className="relative flex-1 truncate">{e.label}</span>
                    {e.sample && (
                      <SampleTag label={sampleTag} className="relative text-muted-foreground" />
                    )}
                    {i === current && (
                      <CornerDownLeft
                        className="relative size-4 text-muted-foreground rtl:-scale-x-100"
                        aria-hidden
                      />
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        </Dialog.Popup>
      </Dialog.Portal>
    </Dialog.Root>
  );
}

import type { ReactNode } from 'react';

/** Re-mounts on every navigation, so each page eases in (CSS only; works before JS loads). */
export default function ConsoleTemplate({ children }: { children: ReactNode }) {
  return <div className="rise flex flex-col gap-6">{children}</div>;
}

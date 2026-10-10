'use client';

import { DirectionProvider } from '@base-ui/react/direction-provider';
import type { ReactNode } from 'react';

/** Tells Base UI components (menus, popovers, sliders) which way the page reads. */
export function Direction({ dir, children }: { dir: 'rtl' | 'ltr'; children: ReactNode }) {
  return <DirectionProvider direction={dir}>{children}</DirectionProvider>;
}

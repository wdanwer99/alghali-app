'use client';

import { Download } from 'lucide-react';
import { useEffect, useState } from 'react';
import { buttonVariants } from '@/components/ui/button';

type Abi = 'armeabi-v7a' | 'arm64-v8a';

/** What Chrome on Android says about itself (User-Agent Client Hints); others say nothing. */
type UaData = { getHighEntropyValues?: (hints: string[]) => Promise<{ bitness?: string }> };

/**
 * The download for this phone (D-135). Chrome reports whether the phone runs 32- or 64-bit
 * Android; when the browser doesn't say, the 32-bit file is offered first, since it installs
 * on nearly every phone and cheap ones often run a 32-bit system. The other file is always
 * one tap away.
 */
export function DownloadButton({
  apkUrl,
  label,
  other,
}: {
  /** Holds `{abi}` where the processor type goes. */
  apkUrl: string;
  label: string;
  other: string;
}) {
  const [abi, setAbi] = useState<Abi>('armeabi-v7a');
  useEffect(() => {
    const ua = (navigator as Navigator & { userAgentData?: UaData }).userAgentData;
    ua?.getHighEntropyValues?.(['bitness'])
      .then((v) => {
        if (v.bitness === '64') setAbi('arm64-v8a');
      })
      .catch(() => undefined);
  }, []);
  const url = (a: Abi) => apkUrl.replaceAll('{abi}', a);
  const otherAbi: Abi = abi === 'arm64-v8a' ? 'armeabi-v7a' : 'arm64-v8a';
  return (
    <div className="flex flex-col items-stretch gap-2">
      <a href={url(abi)} className={buttonVariants({ size: 'lg' })} download>
        <Download aria-hidden />
        {label}
      </a>
      <a
        href={url(otherAbi)}
        className="text-center text-xs text-muted-foreground underline underline-offset-4"
        download
      >
        {other}
      </a>
    </div>
  );
}

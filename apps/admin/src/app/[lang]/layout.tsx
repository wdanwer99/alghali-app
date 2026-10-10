import type { Metadata } from 'next';
import { IBM_Plex_Sans_Arabic } from 'next/font/google';
import { Direction } from '@/components/direction';
import { dirOf, locales } from '@/i18n/config';
import { getDictionary, getLocale } from '@/i18n/dictionaries';
import '../globals.css';

const plexArabic = IBM_Plex_Sans_Arabic({
  variable: '--font-sans',
  subsets: ['arabic', 'latin'],
  weight: ['400', '500', '700'],
  display: 'swap',
});

export async function generateStaticParams() {
  return locales.map((lang) => ({ lang }));
}

export async function generateMetadata(): Promise<Metadata> {
  const d = await getDictionary();
  return { title: d.app.title, description: d.app.description };
}

export default async function RootLayout({ children }: LayoutProps<'/[lang]'>) {
  const locale = await getLocale();
  const dir = dirOf(locale);
  return (
    <html lang={locale} dir={dir} className={`${plexArabic.variable} h-full antialiased`}>
      <body className="flex min-h-full flex-col bg-background text-foreground">
        <Direction dir={dir}>{children}</Direction>
      </body>
    </html>
  );
}

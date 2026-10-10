import { LanguageSwitch } from '@/components/language-switch';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { getDictionary, getLocale } from '@/i18n/dictionaries';

/** Layout only for M0; the form is wired to Supabase Auth in M1. */
export default async function LoginPage() {
  const [d, locale] = await Promise.all([getDictionary(), getLocale()]);

  return (
    <main className="flex flex-1 items-center justify-center p-4">
      <Card className="w-full max-w-sm">
        <CardHeader>
          <CardTitle>{d.login.title}</CardTitle>
          <CardDescription>{d.login.notReady}</CardDescription>
        </CardHeader>
        <CardContent>
          <form className="flex flex-col gap-4">
            <div className="flex flex-col gap-2">
              <Label htmlFor="email">{d.login.email}</Label>
              <Input id="email" name="email" type="email" autoComplete="email" dir="ltr" disabled />
            </div>
            <div className="flex flex-col gap-2">
              <Label htmlFor="password">{d.login.password}</Label>
              <Input
                id="password"
                name="password"
                type="password"
                autoComplete="current-password"
                dir="ltr"
                disabled
              />
            </div>
            <Button type="submit" disabled>
              {d.login.submit}
            </Button>
          </form>
          <div className="mt-4 flex justify-center">
            <LanguageSwitch current={locale} label={d.nav.switchLanguage} />
          </div>
        </CardContent>
      </Card>
    </main>
  );
}

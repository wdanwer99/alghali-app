import { Suspense } from 'react';
import { PageHeader, PageSkeleton } from '@/components/admin/ui';
import { UsersBoard } from '@/components/admin/users-board';
import { getDictionary, type Dictionary } from '@/i18n/dictionaries';
import { requireAdmin } from '@/lib/auth';
import { searchUsers } from '@/lib/data/users';

const LIMIT = 50;

export default async function UsersPage() {
  const d = await getDictionary();
  return (
    <>
      <PageHeader title={d.users.title} description={d.users.subtitle} />
      <Suspense fallback={<PageSkeleton stats={0} rows={8} />}>
        <UsersList d={d} />
      </Suspense>
    </>
  );
}

async function UsersList({ d }: { d: Dictionary }) {
  const { supabase, admin } = await requireAdmin();
  const users = await searchUsers(supabase, '', LIMIT);
  return (
    <UsersBoard
      initial={users}
      meId={admin.id}
      now={new Date().toISOString()}
      limit={LIMIT}
      t={{ u: d.users, common: d.common, errors: d.errors }}
    />
  );
}

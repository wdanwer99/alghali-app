-- Live alerts (D-142): new rows in notifications reach the open apps over Realtime, so a
-- technician sees a job offer (and a shop a new order) at once even when the push is late
-- or never comes. Row level security (notifications_own) still decides who receives what.
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.notifications;
  end if;
end
$$;

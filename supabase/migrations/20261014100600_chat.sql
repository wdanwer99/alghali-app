-- M2 chat between a buyer and a shop (text and voice notes, D-033), delivered live with
-- Supabase Realtime, plus storage policies for the private M2 buckets.

create table public.conversations (
  id              uuid primary key default gen_random_uuid(),
  buyer_id        uuid not null references auth.users (id) on delete cascade,
  shop_id         uuid not null references public.shops (id) on delete cascade,
  sub_order_id    uuid references public.sub_orders (id) on delete set null,
  last_message_at timestamptz,
  buyer_read_at   timestamptz,
  shop_read_at    timestamptz,
  created_at      timestamptz not null default now(),
  unique nulls not distinct (buyer_id, shop_id, sub_order_id)
);
create index conversations_shop_idx on public.conversations (shop_id, last_message_at desc nulls last);
create index conversations_buyer_idx on public.conversations (buyer_id, last_message_at desc nulls last);

create table public.messages (
  id              uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  sender_id       uuid not null default auth.uid() references auth.users (id) on delete cascade,
  body            text check (char_length(btrim(body)) between 1 and 2000),
  voice_key       text check (char_length(voice_key) <= 300),
  voice_secs      integer check (voice_secs between 1 and 60),
  created_at      timestamptz not null default now(),
  check (body is not null or (voice_key is not null and voice_secs is not null))
);
create index messages_conversation_idx on public.messages (conversation_id, created_at);

create function public.is_conversation_participant(p_conversation_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.conversations c
                 where c.id = p_conversation_id
                   and (c.buyer_id = auth.uid() or public.is_shop_member(c.shop_id)));
$$;

-- Keeps the conversation's last activity and tells the other side.
create function public.tg_messages_after_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  c public.conversations;
begin
  update public.conversations set last_message_at = new.created_at,
         buyer_read_at = case when buyer_id = new.sender_id then new.created_at else buyer_read_at end,
         shop_read_at = case when buyer_id <> new.sender_id then new.created_at else shop_read_at end
   where id = new.conversation_id
  returning * into c;
  if c.buyer_id = new.sender_id then
    perform public.notify_shop(c.shop_id, 'NEW_MESSAGE', jsonb_build_object('conversation_id', c.id));
  else
    perform public.notify(c.buyer_id, 'NEW_MESSAGE', jsonb_build_object('conversation_id', c.id, 'shop_id', c.shop_id));
  end if;
  return null;
end
$$;

create function public.tg_messages_before_insert()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.body := nullif(btrim(coalesce(new.body, '')), '');
  if new.voice_key is not null and new.voice_key not like new.conversation_id::text || '/%' then
    raise exception 'INVALID_VOICE_KEY' using errcode = '22023';
  end if;
  return new;
end
$$;

create trigger messages_before_insert before insert on public.messages
  for each row execute function public.tg_messages_before_insert();
create trigger messages_after_insert after insert on public.messages
  for each row execute function public.tg_messages_after_insert();

-- The buyer opens (or reopens) a chat with a shop, optionally about one of their orders.
create function public.start_conversation(p_shop_id uuid, p_sub_order_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := public.require_user();
  v_row public.conversations;
begin
  if not exists (select 1 from public.shops s where s.id = p_shop_id and s.status = 'APPROVED') then
    raise exception 'SHOP_NOT_FOUND' using errcode = 'P0002';
  end if;
  if p_sub_order_id is not null and not exists (
       select 1 from public.sub_orders s join public.orders o on o.id = s.order_id
       where s.id = p_sub_order_id and s.shop_id = p_shop_id and o.buyer_id = v_uid) then
    raise exception 'SUBORDER_NOT_FOUND' using errcode = 'P0002';
  end if;
  insert into public.conversations (buyer_id, shop_id, sub_order_id) values (v_uid, p_shop_id, p_sub_order_id)
  on conflict (buyer_id, shop_id, sub_order_id) do update set buyer_id = excluded.buyer_id
  returning * into v_row;
  return to_jsonb(v_row);
end
$$;

-- The shop opens a chat with the buyer of one of its orders.
create function public.shop_start_conversation(p_sub_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_shop  uuid := public.require_sub_order_shop(p_sub_order_id);
  v_buyer uuid;
  v_row   public.conversations;
begin
  select o.buyer_id into v_buyer from public.sub_orders s join public.orders o on o.id = s.order_id
   where s.id = p_sub_order_id;
  insert into public.conversations (buyer_id, shop_id, sub_order_id) values (v_buyer, v_shop, p_sub_order_id)
  on conflict (buyer_id, shop_id, sub_order_id) do update set shop_id = excluded.shop_id
  returning * into v_row;
  return to_jsonb(v_row);
end
$$;

create function public.mark_conversation_read(p_conversation_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := public.require_user();
begin
  update public.conversations
     set buyer_read_at = case when buyer_id = v_uid then now() else buyer_read_at end,
         shop_read_at = case when buyer_id <> v_uid and public.is_shop_member(shop_id) then now() else shop_read_at end
   where id = p_conversation_id and public.is_conversation_participant(id);
  if not found then raise exception 'CONVERSATION_NOT_FOUND' using errcode = 'P0002'; end if;
end
$$;

-- The shop's inbox: one row per conversation with the buyer's first name, the last
-- message and whether the shop has read it.
create function public.shop_conversations(p_shop_id uuid, p_limit integer default 50)
returns setof jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform public.require_shop(p_shop_id);
  return query
    select to_jsonb(c)
      || jsonb_build_object(
           'buyer_name', pr.display_name,
           'order_ref', (select o.ref from public.sub_orders s join public.orders o on o.id = s.order_id
                         where s.id = c.sub_order_id),
           'last', (select jsonb_build_object('body', m.body, 'voice_secs', m.voice_secs, 'at', m.created_at,
                                              'mine', m.sender_id <> c.buyer_id)
                    from public.messages m where m.conversation_id = c.id order by m.created_at desc limit 1),
           'unread', c.last_message_at > coalesce(c.shop_read_at, '-infinity'))
    from public.conversations c join public.profiles pr on pr.id = c.buyer_id
    where c.shop_id = p_shop_id and c.last_message_at is not null
    order by c.last_message_at desc
    limit least(greatest(coalesce(p_limit, 50), 1), 200);
end
$$;

alter table public.conversations enable row level security;
alter table public.messages enable row level security;
revoke all on public.conversations, public.messages from anon, authenticated;
grant select on public.conversations to authenticated;
grant select, insert on public.messages to authenticated;

create policy conversations_read on public.conversations for select to authenticated
  using (buyer_id = (select auth.uid()) or public.is_shop_member(shop_id) or (select public.is_admin()));
create policy messages_read on public.messages for select to authenticated
  using (public.is_conversation_participant(conversation_id) or (select public.is_admin()));
create policy messages_send on public.messages for insert to authenticated
  with check (sender_id = (select auth.uid()) and public.is_conversation_participant(conversation_id));

-- Live messages for the apps (RLS still decides who receives what).
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.messages;
  end if;
end
$$;

revoke all on function
  public.is_conversation_participant(uuid), public.tg_messages_after_insert(), public.tg_messages_before_insert(),
  public.start_conversation(uuid, uuid), public.shop_start_conversation(uuid), public.mark_conversation_read(uuid),
  public.shop_conversations(uuid, integer)
from public, anon, authenticated;

grant execute on function public.is_conversation_participant(uuid) to authenticated;
grant execute on function
  public.start_conversation(uuid, uuid), public.shop_start_conversation(uuid), public.mark_conversation_read(uuid),
  public.shop_conversations(uuid, integer)
to authenticated;

-- ------------------------------------------------------------------ storage policies
-- receipts/{user id}/…: the buyer uploads and reads their own; admins read all.
create policy receipts_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'receipts' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy receipts_select on storage.objects for select to authenticated
  using (bucket_id = 'receipts' and ((storage.foldername(name))[1] = (select auth.uid())::text
                                     or (select public.is_admin())));

-- request-photos/{user id}/…: the buyer's own; shops see the photos of open requests.
create policy request_photos_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'request-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy request_photos_select on storage.objects for select to authenticated
  using (bucket_id = 'request-photos' and (
    (storage.foldername(name))[1] = (select auth.uid())::text
    or (select public.is_admin())
    or exists (select 1 from public.part_requests r
               where r.status = 'OPEN' and name = any (r.image_keys)
                 and exists (select 1 from public.shop_members m join public.shops s on s.id = m.shop_id
                             where m.user_id = (select auth.uid()) and s.status = 'APPROVED'))));

-- voice-notes/{conversation id}/…: the two sides of the conversation.
create policy voice_notes_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'voice-notes'
              and public.is_conversation_participant(public.try_uuid((storage.foldername(name))[1])));
create policy voice_notes_select on storage.objects for select to authenticated
  using (bucket_id = 'voice-notes'
         and public.is_conversation_participant(public.try_uuid((storage.foldername(name))[1])));

-- M3 notifications dispatcher. Every alert is still a row in `notifications` (D-091);
-- this adds which app it is for, Arabic and English wording per code, and a delivery
-- queue: one push per device of the right app, sent by the `notify-dispatch` Edge
-- Function (FCM, D-061). SMS and WhatsApp are stubs: the deliveries are recorded as
-- STUB so a provider can be plugged in later without changing the senders.
--
-- The queue is the `notification_deliveries` table (D-101): PENDING rows are claimed
-- with SKIP LOCKED, retried with backoff, and visible to admins. pg_cron pokes the Edge
-- Function through pg_net once a minute when something is waiting.

alter table public.notifications add column app text check (app in ('buyer', 'partner', 'admin'));

-- Which app a code is for by default, and whether it also goes by SMS (once a provider exists).
create table public.notification_codes (
  code text primary key check (code ~ '^[A-Z][A-Z_]*$'),
  app  text not null check (app in ('buyer', 'partner', 'admin')),
  sms  boolean not null default false
);

-- Wording per code and language. {name} placeholders are filled from the payload; keys
-- ending in _at are shown as Khartoum date and time, keys ending in _sdg as money.
create table public.notification_templates (
  code   text not null references public.notification_codes (code) on delete cascade,
  locale text not null check (locale in ('ar', 'en')),
  title  text not null check (char_length(title) between 1 and 100),
  body   text not null check (char_length(body) between 1 and 300),
  primary key (code, locale)
);

insert into public.notification_codes (code, app, sms) values
  ('ORDER_PLACED',             'buyer',   false),
  ('PAYMENT_CONFIRMED',        'buyer',   true),
  ('PAYMENT_REJECTED',         'buyer',   true),
  ('ORDER_READY',              'buyer',   false),
  ('ORDER_HANDED_OVER',        'buyer',   false),
  ('ORDER_DELIVERED',          'buyer',   false),
  ('ORDER_CANCELLED',          'buyer',   false),
  ('ORDER_REJECTED_BY_SHOP',   'buyer',   true),
  ('RETURN_APPROVED',          'buyer',   false),
  ('RETURN_DECLINED',          'buyer',   false),
  ('REFUND_CREATED',           'buyer',   false),
  ('REFUND_PAID',              'buyer',   true),
  ('NEW_OFFER',                'buyer',   false),
  ('NEW_MESSAGE',              'buyer',   false),
  ('BOOKING_ACCEPTED',         'buyer',   true),
  ('BOOKING_REASSIGNED',       'buyer',   false),
  ('BOOKING_NEEDS_RESCHEDULE', 'buyer',   true),
  ('BOOKING_CANCELLED',        'buyer',   true),
  ('BOOKING_COMPLETED',        'buyer',   false),
  ('TECH_EN_ROUTE',            'buyer',   true),
  ('TECH_ARRIVED',             'buyer',   false),
  ('PART_DOES_NOT_FIT',        'buyer',   false),
  ('BOOKING_REMINDER_DAY',     'buyer',   true),
  ('BOOKING_REMINDER_HOUR',    'buyer',   true),
  ('DISPUTE_REPLY',            'buyer',   false),
  ('DISPUTE_RESOLVED',         'buyer',   false),
  ('NEW_ORDER',                'partner', true),
  ('NEW_PART_REQUEST',         'partner', false),
  ('RETURN_REQUESTED',         'partner', false),
  ('PAYOUT_PAID',              'partner', false),
  ('NEW_JOB_OFFER',            'partner', true),
  ('TECHNICIAN_STATUS',        'partner', false),
  ('PARTS_READY',              'partner', false),
  ('TECH_WILL_COLLECT',        'partner', false),
  ('NEW_REVIEW',               'partner', false),
  ('SHOP_NOT_ACKNOWLEDGED',    'admin',   false),
  ('JOB_CODE_LOCKED',          'admin',   false),
  ('DISPUTE_OPENED',           'admin',   false);

insert into public.notification_templates (code, locale, title, body) values
  ('ORDER_PLACED', 'ar', 'تم استلام طلبك', 'رقم الطلب {ref}. سنُبلغك بكل خطوة.'),
  ('ORDER_PLACED', 'en', 'Order received', 'Order {ref}. We''ll keep you posted.'),
  ('PAYMENT_CONFIRMED', 'ar', 'تم تأكيد الدفع', 'وصل تحويلك للطلب {ref}، والمحلات تجهّزه الآن.'),
  ('PAYMENT_CONFIRMED', 'en', 'Payment confirmed', 'Your transfer for order {ref} arrived; the shops are preparing it.'),
  ('PAYMENT_REJECTED', 'ar', 'لم نتمكن من تأكيد الدفع', 'راجع إيصال الطلب {ref} وأرسله مرة أخرى قبل {pay_by}.'),
  ('PAYMENT_REJECTED', 'en', 'Payment not confirmed', 'Check the receipt for order {ref} and send it again before {pay_by}.'),
  ('ORDER_READY', 'ar', 'طلبك جاهز', 'الطلب {ref} جاهز في المحل.'),
  ('ORDER_READY', 'en', 'Your order is ready', 'Order {ref} is ready at the shop.'),
  ('ORDER_HANDED_OVER', 'ar', 'تم تسليم الطلب', 'خرج الطلب {ref} من المحل.'),
  ('ORDER_HANDED_OVER', 'en', 'Order handed over', 'Order {ref} has left the shop.'),
  ('ORDER_DELIVERED', 'ar', 'تم التوصيل', 'وصل الطلب {ref}. نتمنى أن يعجبك.'),
  ('ORDER_DELIVERED', 'en', 'Delivered', 'Order {ref} was delivered.'),
  ('ORDER_CANCELLED', 'ar', 'أُلغي الطلب', 'أُلغي الطلب {ref}.'),
  ('ORDER_CANCELLED', 'en', 'Order cancelled', 'Order {ref} was cancelled.'),
  ('ORDER_REJECTED_BY_SHOP', 'ar', 'المحل لا يستطيع توفير القطعة', 'اعتذر المحل عن جزء من الطلب {ref}، وسنعيد لك المبلغ.'),
  ('ORDER_REJECTED_BY_SHOP', 'en', 'The shop can''t supply it', 'A shop declined part of order {ref}; you''ll get that money back.'),
  ('RETURN_APPROVED', 'ar', 'تمت الموافقة على الإرجاع', 'وافقنا على إرجاع جزء من الطلب {ref}.'),
  ('RETURN_APPROVED', 'en', 'Return approved', 'The return on order {ref} was approved.'),
  ('RETURN_DECLINED', 'ar', 'لم تتم الموافقة على الإرجاع', 'لم نوافق على إرجاع جزء من الطلب {ref}: {reason}'),
  ('RETURN_DECLINED', 'en', 'Return declined', 'The return on order {ref} was declined: {reason}'),
  ('REFUND_CREATED', 'ar', 'سنعيد لك مبلغًا', 'سنحوّل لك {amount_sdg} عبر بنكك قريبًا.'),
  ('REFUND_CREATED', 'en', 'Refund on its way', 'We''ll send you {amount_sdg} by Bankak soon.'),
  ('REFUND_PAID', 'ar', 'تم تحويل المبلغ', 'حوّلنا لك {amount_sdg} عبر بنكك. رقم العملية {txn}.'),
  ('REFUND_PAID', 'en', 'Refund sent', 'We sent you {amount_sdg} by Bankak, transaction {txn}.'),
  ('NEW_OFFER', 'ar', 'عرض جديد على طلبك', 'وصلك عرض بسعر {price_sdg}.'),
  ('NEW_OFFER', 'en', 'New offer on your request', 'A shop offered it for {price_sdg}.'),
  ('NEW_MESSAGE', 'ar', 'رسالة جديدة', 'لديك رسالة جديدة.'),
  ('NEW_MESSAGE', 'en', 'New message', 'You have a new message.'),
  ('BOOKING_ACCEPTED', 'ar', 'تم تأكيد موعد التركيب', 'الفني قبل موعد التركيب {ref} يوم {start_at}.'),
  ('BOOKING_ACCEPTED', 'en', 'Fitting confirmed', 'The technician accepted fitting {ref} for {start_at}.'),
  ('BOOKING_REASSIGNED', 'ar', 'فني آخر لموعدك', 'نعرض موعد التركيب {ref} على فني آخر في نفس الوقت.'),
  ('BOOKING_REASSIGNED', 'en', 'Another technician', 'We''re offering fitting {ref} to another technician at the same time.'),
  ('BOOKING_NEEDS_RESCHEDULE', 'ar', 'اختر موعدًا جديدًا', 'لا يوجد فني متاح لموعد التركيب {ref}. اختر وقتًا آخر أو ألغِ واسترد المبلغ كاملًا.'),
  ('BOOKING_NEEDS_RESCHEDULE', 'en', 'Pick a new time', 'No technician is free for fitting {ref}. Pick another time, or cancel for a full refund.'),
  ('BOOKING_CANCELLED', 'ar', 'أُلغي موعد التركيب', 'أُلغي موعد التركيب {ref}.'),
  ('BOOKING_CANCELLED', 'en', 'Fitting cancelled', 'Fitting {ref} was cancelled.'),
  ('BOOKING_COMPLETED', 'ar', 'تم التركيب', 'انتهى التركيب {ref}. قيّم الفني والمحل.'),
  ('BOOKING_COMPLETED', 'en', 'Fitting done', 'Fitting {ref} is done. Rate the technician and the shop.'),
  ('TECH_EN_ROUTE', 'ar', 'الفني في الطريق', 'الفني في طريقه إليك لموعد التركيب {ref}.'),
  ('TECH_EN_ROUTE', 'en', 'Technician on the way', 'Your technician is on the way for fitting {ref}.'),
  ('TECH_ARRIVED', 'ar', 'بدأ التركيب', 'بدأ الفني العمل على التركيب {ref}.'),
  ('TECH_ARRIVED', 'en', 'Work started', 'The technician started fitting {ref}.'),
  ('PART_DOES_NOT_FIT', 'ar', 'القطعة لا تناسب السيارة', 'لم يركّب الفني القطعة في الموعد {ref}. تدفع رسوم المشوار فقط، وفتحنا طلب إرجاع.'),
  ('PART_DOES_NOT_FIT', 'en', 'The part doesn''t fit', 'The part couldn''t be fitted ({ref}). You pay the travel fee only; we opened a return.'),
  ('BOOKING_REMINDER_DAY', 'ar', 'تذكير بموعد التركيب', 'موعد التركيب {ref} غدًا {start_at}.'),
  ('BOOKING_REMINDER_DAY', 'en', 'Fitting tomorrow', 'Fitting {ref} is at {start_at}.'),
  ('BOOKING_REMINDER_HOUR', 'ar', 'موعد التركيب بعد ساعة', 'موعد التركيب {ref} الساعة {start_at}.'),
  ('BOOKING_REMINDER_HOUR', 'en', 'Fitting in an hour', 'Fitting {ref} starts at {start_at}.'),
  ('DISPUTE_REPLY', 'ar', 'رد على الشكوى', 'هناك رد جديد على الشكوى.'),
  ('DISPUTE_REPLY', 'en', 'Reply on your complaint', 'There''s a new reply on the complaint.'),
  ('DISPUTE_RESOLVED', 'ar', 'أُغلقت الشكوى', 'تم البت في الشكوى: {resolution}'),
  ('DISPUTE_RESOLVED', 'en', 'Complaint closed', 'The complaint was decided: {resolution}'),
  ('NEW_ORDER', 'ar', 'طلب جديد', 'طلب جديد رقم {ref}. اضغط للقبول.'),
  ('NEW_ORDER', 'en', 'New order', 'New order {ref}. Tap to accept.'),
  ('NEW_PART_REQUEST', 'ar', 'طلب قطعة جديد', 'زبون يبحث عن قطعة قد تكون عندك.'),
  ('NEW_PART_REQUEST', 'en', 'New part request', 'A buyer is looking for a part you may have.'),
  ('RETURN_REQUESTED', 'ar', 'طلب إرجاع', 'طلب الزبون إرجاع الطلب {ref}: {reason}'),
  ('RETURN_REQUESTED', 'en', 'Return requested', 'The buyer wants to return order {ref}: {reason}'),
  ('PAYOUT_PAID', 'ar', 'تم تحويل مستحقاتك', 'حوّلنا لك {amount_sdg} عبر بنكك. رقم العملية {txn}.'),
  ('PAYOUT_PAID', 'en', 'Payout sent', 'We sent you {amount_sdg} by Bankak, transaction {txn}.'),
  ('NEW_JOB_OFFER', 'ar', 'عرض عمل جديد', 'تركيب {ref} يوم {start_at}. اقبل أو اعتذر قبل انتهاء المهلة.'),
  ('NEW_JOB_OFFER', 'en', 'New job offer', 'Fitting {ref} at {start_at}. Accept or decline before it times out.'),
  ('TECHNICIAN_STATUS', 'ar', 'تحديث على حسابك كفني', 'تغيّرت حالة حسابك كفني.'),
  ('TECHNICIAN_STATUS', 'en', 'Technician account update', 'The status of your technician account changed.'),
  ('PARTS_READY', 'ar', 'القطع جاهزة للاستلام', 'قطع الطلب {ref} جاهزة في المحل لموعد التركيب.'),
  ('PARTS_READY', 'en', 'Parts ready to collect', 'The parts for order {ref} are ready at the shop for your fitting.'),
  ('TECH_WILL_COLLECT', 'ar', 'فني سيستلم القطع', '{technician} سيستلم قطع الطلب قبل موعد التركيب {start_at}.'),
  ('TECH_WILL_COLLECT', 'en', 'A technician will collect', '{technician} will collect the parts before the fitting at {start_at}.'),
  ('NEW_REVIEW', 'ar', 'تقييم جديد', 'حصلت على تقييم {rating} من 5.'),
  ('NEW_REVIEW', 'en', 'New review', 'You got a {rating} out of 5 review.'),
  ('SHOP_NOT_ACKNOWLEDGED', 'ar', 'طلب لم يقبله المحل', 'الطلب {ref} مؤكد منذ 30 دقيقة ولم يقبله المحل.'),
  ('SHOP_NOT_ACKNOWLEDGED', 'en', 'Order not accepted', 'Order {ref} has been confirmed for 30 minutes without the shop accepting.'),
  ('JOB_CODE_LOCKED', 'ar', 'قُفل رمز التركيب', 'أُدخل رمز خاطئ 5 مرات في التركيب {ref}.'),
  ('JOB_CODE_LOCKED', 'en', 'Job code locked', 'A wrong code was entered 5 times on fitting {ref}.'),
  ('DISPUTE_OPENED', 'ar', 'شكوى جديدة', 'فُتحت شكوى جديدة.'),
  ('DISPUTE_OPENED', 'en', 'New complaint', 'A new complaint was opened.');

-- The app a notification is for: as given, else the code's default, else the buyer app.
create function public.tg_notifications_app()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.app is null then
    new.app := coalesce((select c.app from public.notification_codes c where c.code = new.code), 'buyer');
  end if;
  return new;
end
$$;
create trigger notifications_app before insert on public.notifications
  for each row execute function public.tg_notifications_app();

-- notify_shop() from M2: shop alerts are for the partner app.
create or replace function public.notify_shop(p_shop_id uuid, p_code text, p_payload jsonb default '{}')
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.notifications (user_id, code, payload, app)
  select m.user_id, p_code, coalesce(p_payload, '{}') || jsonb_build_object('shop_id', p_shop_id), 'partner'
  from public.shop_members m where m.shop_id = p_shop_id;
$$;

-- For a technician (partner app).
create function public.notify_partner(p_user_id uuid, p_code text, p_payload jsonb default '{}')
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.notifications (user_id, code, payload, app) values (p_user_id, p_code, coalesce(p_payload, '{}'), 'partner');
$$;

-- For every admin (the admin console's alerts).
create function public.notify_admins(p_code text, p_payload jsonb default '{}')
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.notifications (user_id, code, payload, app)
  select r.user_id, p_code, coalesce(p_payload, '{}'), 'admin' from public.user_roles r where r.role = 'ADMIN';
$$;

-- ------------------------------------------------------------------ deliveries
create type public.notify_channel as enum ('PUSH', 'SMS', 'WHATSAPP');

create table public.notification_deliveries (
  id              uuid primary key default gen_random_uuid(),
  notification_id uuid not null references public.notifications (id) on delete cascade,
  channel         public.notify_channel not null,
  device_id       uuid references public.devices (id) on delete set null,
  target          text not null,                 -- FCM token or phone number
  locale          text not null default 'ar' check (locale in ('ar', 'en')),
  status          text not null default 'PENDING'
                  check (status in ('PENDING', 'SENDING', 'SENT', 'FAILED', 'STUB')),
  attempts        integer not null default 0,
  next_attempt_at timestamptz not null default now(),
  last_error      text,
  provider_ref    text,
  sent_at         timestamptz,
  created_at      timestamptz not null default now()
);
create index notification_deliveries_due_idx on public.notification_deliveries (next_attempt_at) where status = 'PENDING';
create index notification_deliveries_notification_idx on public.notification_deliveries (notification_id);

-- A push to every device the user has for that app; an SMS stub for key alerts when
-- the user has a phone (logged until an SMS provider is chosen, D-061).
create function public.tg_notifications_deliver()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_locale text;
  v_phone  text;
begin
  select p.locale, p.phone into v_locale, v_phone from public.profiles p where p.id = new.user_id;
  insert into public.notification_deliveries (notification_id, channel, device_id, target, locale)
  select new.id, 'PUSH', d.id, d.fcm_token, coalesce(d.locale, v_locale, 'ar')
  from public.devices d where d.user_id = new.user_id and d.app = new.app;
  if v_phone is not null and exists (select 1 from public.notification_codes c where c.code = new.code and c.sms) then
    insert into public.notification_deliveries (notification_id, channel, target, locale, status, last_error)
    values (new.id, 'SMS', v_phone, coalesce(v_locale, 'ar'), 'STUB', 'NO_SMS_PROVIDER');
  end if;
  return null;
end
$$;
create trigger notifications_deliver after insert on public.notifications
  for each row execute function public.tg_notifications_deliver();

-- For `notify-dispatch` (service role only): claims up to p_limit due pushes with what is
-- needed to word them. Claimed rows are SENDING until reported; a crashed run's rows go
-- back to PENDING after 5 minutes.
create function public.notify_claim(p_limit integer default 50)
returns setof jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.notification_deliveries set status = 'PENDING'
   where status = 'SENDING' and next_attempt_at < now() - interval '5 minutes';
  return query
    with due as (
      select d.id from public.notification_deliveries d
      where d.status = 'PENDING' and d.channel = 'PUSH' and d.next_attempt_at <= now()
      order by d.next_attempt_at
      limit least(greatest(coalesce(p_limit, 50), 1), 500)
      for update skip locked
    ),
    claimed as (
      update public.notification_deliveries d
         set status = 'SENDING', attempts = d.attempts + 1, next_attempt_at = now()
        from due where d.id = due.id
      returning d.*
    )
    select jsonb_build_object(
      'id', c.id, 'channel', c.channel, 'target', c.target, 'locale', c.locale, 'attempts', c.attempts,
      'notification_id', n.id, 'code', n.code, 'app', n.app, 'payload', n.payload,
      'title', coalesce(t.title, n.code), 'body', coalesce(t.body, ''))
    from claimed c
    join public.notifications n on n.id = c.notification_id
    left join public.notification_templates t on t.code = n.code and t.locale = c.locale;
end
$$;

-- p_results = [{id, ok, error?, provider_ref?, retry?, stub?}]. Failures are retried with
-- backoff (1, 2, 4, 8 minutes) up to 5 attempts; a token FCM no longer knows is dropped.
create function public.notify_report(p_results jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  r   jsonb;
  d   public.notification_deliveries;
  v_n integer := 0;
begin
  for r in select * from jsonb_array_elements(coalesce(p_results, '[]')) loop
    select * into d from public.notification_deliveries where id = (r ->> 'id')::uuid and status = 'SENDING' for update;
    continue when d.id is null;
    if (r ->> 'stub')::boolean then
      update public.notification_deliveries set status = 'STUB', last_error = r ->> 'error' where id = d.id;
    elsif (r ->> 'ok')::boolean then
      update public.notification_deliveries set status = 'SENT', sent_at = now(), provider_ref = r ->> 'provider_ref',
                                                last_error = null
       where id = d.id;
    elsif coalesce((r ->> 'retry')::boolean, true) and d.attempts < 5 then
      update public.notification_deliveries
         set status = 'PENDING', last_error = left(r ->> 'error', 300),
             next_attempt_at = now() + make_interval(mins => power(2, d.attempts - 1)::integer)
       where id = d.id;
    else
      update public.notification_deliveries set status = 'FAILED', last_error = left(r ->> 'error', 300) where id = d.id;
      if r ->> 'error' = 'UNREGISTERED' then
        delete from public.devices where id = d.device_id;
      end if;
    end if;
    v_n := v_n + 1;
  end loop;
  return v_n;
end
$$;

-- Calls notify-dispatch when pushes are waiting. The function's address and its token
-- live in Vault (`notify_dispatch_url`, `notify_dispatch_token`), set per project by
-- `pnpm notify:setup <dev|test>`; without them nothing is sent and pushes wait.
create function public.kick_notify_dispatch()
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_url   text;
  v_token text;
begin
  if not exists (select 1 from public.notification_deliveries d where d.status = 'PENDING' and d.next_attempt_at <= now()) then
    return false;
  end if;
  begin
    select s.decrypted_secret into v_url from vault.decrypted_secrets s where s.name = 'notify_dispatch_url';
    select s.decrypted_secret into v_token from vault.decrypted_secrets s where s.name = 'notify_dispatch_token';
  exception when others then
    return false;
  end;
  if v_url is null or v_token is null then return false; end if;
  perform net.http_post(url := v_url, body := '{}'::jsonb,
                        headers := jsonb_build_object('Authorization', 'Bearer ' || v_token,
                                                      'Content-Type', 'application/json'),
                        timeout_milliseconds := 10000);
  return true;
end
$$;

select cron.schedule('notify-dispatch', '* * * * *', $$select public.kick_notify_dispatch()$$);
-- Delivery rows older than 30 days are of no more use.
select cron.schedule('notify-cleanup', '17 3 * * *',
  $$delete from public.notification_deliveries where created_at < now() - interval '30 days'$$);

-- ------------------------------------------------------------------ RLS + grants
alter table public.notification_codes enable row level security;
alter table public.notification_templates enable row level security;
alter table public.notification_deliveries enable row level security;
revoke all on public.notification_codes, public.notification_templates, public.notification_deliveries
from anon, authenticated;
grant select on public.notification_codes, public.notification_templates, public.notification_deliveries to authenticated;
-- Admins can read and fix the wording and see what was sent.
grant insert, update on public.notification_templates to authenticated;
create policy notification_codes_read on public.notification_codes for select to authenticated using (true);
create policy notification_templates_read on public.notification_templates for select to authenticated using (true);
create policy notification_templates_admin on public.notification_templates for update to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));
create policy notification_templates_admin_insert on public.notification_templates for insert to authenticated
  with check ((select public.is_admin()));
create policy notification_deliveries_admin on public.notification_deliveries for select to authenticated
  using ((select public.is_admin()));

revoke all on function
  public.tg_notifications_app(), public.notify_partner(uuid, text, jsonb), public.notify_admins(text, jsonb),
  public.tg_notifications_deliver(), public.notify_claim(integer), public.notify_report(jsonb),
  public.kick_notify_dispatch()
from public, anon, authenticated;
grant execute on function public.notify_claim(integer), public.notify_report(jsonb) to service_role;

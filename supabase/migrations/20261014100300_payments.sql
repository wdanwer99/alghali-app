-- M2 payments: Bankak receipts and the admin confirmation queue (D-017, D-054), refunds
-- the platform sends back, and the buyer's refund account.

-- Digits only, from Arabic-Indic or Western digits with spaces/dashes; null if not 6–20 digits.
create function public.clean_txn(p text)
returns text
language sql
immutable
set search_path = ''
as $$
  select nullif(substring(
    regexp_replace(translate(coalesce(p, ''), '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹', '01234567890123456789'), '[\s-]', '', 'g')
    from '^[0-9]{6,20}$'), '');
$$;

-- The buyer reports a transfer: the transaction number, a receipt screenshot
-- (uploaded first to receipts/{user id}/…), or both. Allowed until pay_by, also after
-- a rejection. Moves the order to "payment being checked".
create function public.submit_bankak_receipt(
  p_order_id    uuid,
  p_txn_no      text default null,
  p_receipt_key text default null,
  p_idem        uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid  uuid := public.require_user();
  v_prev jsonb := public.idem_begin(p_idem, 'submit_bankak_receipt');
  o      public.orders;
  v_pay  public.payments;
  v_txn  text := public.clean_txn(p_txn_no);
  v_key  text := nullif(btrim(coalesce(p_receipt_key, '')), '');
  s      record;
begin
  if v_prev is not null then return v_prev; end if;
  select * into o from public.orders where id = p_order_id and buyer_id = v_uid;
  if o.id is null then raise exception 'ORDER_NOT_FOUND' using errcode = 'P0002'; end if;
  select * into v_pay from public.payments p
   where p.order_id = o.id and p.method = 'BANKAK' and p.purpose = 'ORDER' for update;
  if v_pay.id is null or v_pay.status not in ('AWAITING_TRANSFER', 'REJECTED') then
    raise exception 'NOT_AWAITING_PAYMENT' using errcode = 'PT409';
  end if;
  if o.pay_by < now() then raise exception 'PAYMENT_EXPIRED' using errcode = 'PT409'; end if;
  if nullif(btrim(coalesce(p_txn_no, '')), '') is not null and v_txn is null then
    raise exception 'INVALID_TXN' using errcode = '22023';
  end if;
  if v_txn is null and v_key is null then raise exception 'RECEIPT_REQUIRED' using errcode = '22023'; end if;
  if v_key is not null and (v_key not like v_uid::text || '/%'
     or not exists (select 1 from storage.objects so where so.bucket_id = 'receipts' and so.name = v_key)) then
    raise exception 'INVALID_RECEIPT_KEY' using errcode = '22023';
  end if;

  begin
    update public.payments set bankak_txn_no = v_txn, receipt_key = v_key, submitted_at = now(),
                               reject_reason = null
     where id = v_pay.id;
    perform public.transition_payment(v_pay.id, 'RECEIPT_SUBMITTED', 'BUYER');
  exception when unique_violation then
    raise exception 'DUPLICATE_TXN' using errcode = 'PT409';
  end;
  for s in select x.id from public.sub_orders x where x.order_id = o.id and x.status = 'PENDING_PAYMENT' loop
    perform public.transition_suborder(s.id, 'PAYMENT_REVIEW', 'BUYER');
  end loop;
  return public.idem_finish(p_idem, 'submit_bankak_receipt', public.order_json(o.id));
end
$$;

-- Admin, after finding the transfer on the Bankak statement. The transaction number is
-- required here (typed from the statement when the buyer only sent a screenshot), so the
-- same transfer can never confirm two payments.
create function public.admin_confirm_payment(
  p_payment_id  uuid,
  p_txn_no      text default null,
  p_ref_in_note boolean default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid := public.require_admin();
  v_pay   public.payments;
  o       public.orders;
  v_txn   text;
  s       record;
begin
  select * into v_pay from public.payments where id = p_payment_id for update;
  if v_pay.id is null then raise exception 'PAYMENT_NOT_FOUND' using errcode = 'P0002'; end if;
  if v_pay.status <> 'RECEIPT_SUBMITTED' then raise exception 'NOT_UNDER_REVIEW' using errcode = 'PT409'; end if;
  v_txn := coalesce(public.clean_txn(p_txn_no), v_pay.bankak_txn_no);
  if v_txn is null then raise exception 'TXN_REQUIRED' using errcode = '22023'; end if;
  select * into o from public.orders where id = v_pay.order_id;

  begin
    update public.payments
       set bankak_txn_no = v_txn, reviewed_by = v_admin, reviewed_at = now(), ref_in_note = p_ref_in_note
     where id = v_pay.id;
  exception when unique_violation then
    raise exception 'DUPLICATE_TXN' using errcode = 'PT409';
  end;
  perform public.transition_payment(v_pay.id, 'CONFIRMED', 'ADMIN');
  perform public.post_journal('PAYMENT', public.ledger_account('PLATFORM_BANKAK'), public.ledger_account('BUYER_FUNDS_HELD'),
                              v_pay.amount_sdg, o.id, null, v_pay.id);
  for s in select x.id from public.sub_orders x where x.order_id = o.id and x.status = 'PAYMENT_REVIEW' loop
    perform public.transition_suborder(s.id, 'CONFIRMED', 'ADMIN');
  end loop;
  perform public.notify(o.buyer_id, 'PAYMENT_CONFIRMED', jsonb_build_object('order_id', o.id, 'ref', o.ref));
  perform public.audit('CONFIRM_PAYMENT', 'payment', v_pay.id::text, jsonb_build_object('txn', v_txn, 'ref', o.ref));
  return public.order_json(o.id);
end
$$;

-- p_reason: AMOUNT_WRONG, NOT_ON_STATEMENT, DUPLICATE, UNREADABLE or OTHER. The buyer
-- may send a new receipt until pay_by.
create function public.admin_reject_payment(p_payment_id uuid, p_reason text, p_note text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid := public.require_admin();
  v_pay   public.payments;
  o       public.orders;
  s       record;
begin
  if p_reason not in ('AMOUNT_WRONG', 'NOT_ON_STATEMENT', 'DUPLICATE', 'UNREADABLE', 'OTHER') then
    raise exception 'INVALID_REASON' using errcode = '22023';
  end if;
  select * into v_pay from public.payments where id = p_payment_id for update;
  if v_pay.id is null then raise exception 'PAYMENT_NOT_FOUND' using errcode = 'P0002'; end if;
  if v_pay.status <> 'RECEIPT_SUBMITTED' then raise exception 'NOT_UNDER_REVIEW' using errcode = 'PT409'; end if;
  select * into o from public.orders where id = v_pay.order_id;

  update public.payments set reviewed_by = v_admin, reviewed_at = now(), reject_reason = p_reason
   where id = v_pay.id;
  perform public.transition_payment(v_pay.id, 'REJECTED', 'ADMIN', nullif(btrim(coalesce(p_note, '')), ''));
  for s in select x.id from public.sub_orders x where x.order_id = o.id and x.status = 'PAYMENT_REVIEW' loop
    perform public.transition_suborder(s.id, 'PENDING_PAYMENT', 'ADMIN', p_reason);
  end loop;
  perform public.notify(o.buyer_id, 'PAYMENT_REJECTED',
                        jsonb_build_object('order_id', o.id, 'ref', o.ref, 'reason', p_reason, 'pay_by', o.pay_by));
  perform public.audit('REJECT_PAYMENT', 'payment', v_pay.id::text, jsonb_build_object('reason', p_reason, 'ref', o.ref));
  return public.order_json(o.id);
end
$$;

-- Where the buyer wants refunds sent (their own Bankak account number).
create function public.set_refund_account(p_account text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_acc text := public.clean_txn(p_account);
begin
  if nullif(btrim(coalesce(p_account, '')), '') is not null and v_acc is null then
    raise exception 'INVALID_ACCOUNT' using errcode = '22023';
  end if;
  update public.profiles set refund_account = v_acc where id = public.require_user();
end
$$;

-- Admin sent the refund by Bankak; the transaction number is recorded once.
create function public.admin_mark_refund_paid(p_refund_id uuid, p_txn_no text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid := public.require_admin();
  v_txn   text := public.clean_txn(p_txn_no);
  r       public.refunds;
begin
  if v_txn is null then raise exception 'INVALID_TXN' using errcode = '22023'; end if;
  select * into r from public.refunds where id = p_refund_id for update;
  if r.id is null then raise exception 'REFUND_NOT_FOUND' using errcode = 'P0002'; end if;
  if r.status <> 'PENDING' then raise exception 'ALREADY_PAID' using errcode = 'PT409'; end if;
  begin
    update public.refunds set status = 'PAID', bankak_txn_no = v_txn, paid_by = v_admin, paid_at = now()
     where id = r.id;
  exception when unique_violation then
    raise exception 'DUPLICATE_TXN' using errcode = 'PT409';
  end;
  perform public.post_journal('REFUND_PAID', public.ledger_account('REFUNDS_PAYABLE'), public.ledger_account('PLATFORM_BANKAK'),
                              r.amount_sdg, r.order_id, r.sub_order_id, null, null, r.id);
  perform public.notify(r.buyer_id, 'REFUND_PAID',
                        jsonb_build_object('order_id', r.order_id, 'amount_sdg', r.amount_sdg, 'txn', v_txn));
  perform public.audit('REFUND_PAID', 'refund', r.id::text, jsonb_build_object('txn', v_txn));
end
$$;

-- Admin view of one receipt under review: the order, the buyer, the checks (D-054).
create function public.admin_payment_queue()
returns setof jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform public.require_admin();
  return query
    select jsonb_build_object(
      'payment_id', p.id, 'order_id', o.id, 'ref', o.ref, 'amount_sdg', p.amount_sdg,
      'txn', p.bankak_txn_no, 'receipt_key', p.receipt_key, 'submitted_at', p.submitted_at,
      'pay_by', o.pay_by, 'created_at', o.created_at,
      'buyer', jsonb_build_object('id', pr.id, 'name', pr.display_name, 'phone', pr.phone, 'email', pr.email),
      'txn_seen_before', p.bankak_txn_no is not null and exists (
         select 1 from public.payments q where q.bankak_txn_no = p.bankak_txn_no and q.id <> p.id),
      'shops', coalesce((select jsonb_agg(jsonb_build_object('id', sh.id, 'name_ar', sh.name_ar, 'name_en', sh.name_en))
                         from public.sub_orders s join public.shops sh on sh.id = s.shop_id where s.order_id = o.id), '[]'),
      'has_fitting', o.booking_fee_sdg > 0,
      'earlier_rejections', (select count(*) from public.payment_events e
                             where e.payment_id = p.id and e.to_status = 'REJECTED'))
    from public.payments p
    join public.orders o on o.id = p.order_id
    join public.profiles pr on pr.id = o.buyer_id
    where p.status = 'RECEIPT_SUBMITTED'
    order by p.submitted_at;
end
$$;

revoke all on function
  public.clean_txn(text), public.submit_bankak_receipt(uuid, text, text, uuid),
  public.admin_confirm_payment(uuid, text, boolean), public.admin_reject_payment(uuid, text, text),
  public.set_refund_account(text), public.admin_mark_refund_paid(uuid, text), public.admin_payment_queue()
from public, anon, authenticated;

grant execute on function
  public.submit_bankak_receipt(uuid, text, text, uuid),
  public.admin_confirm_payment(uuid, text, boolean), public.admin_reject_payment(uuid, text, text),
  public.set_refund_account(text), public.admin_mark_refund_paid(uuid, text), public.admin_payment_queue()
to authenticated;

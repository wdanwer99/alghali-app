-- booking_json() from 20261015100200, with each item's job type code, so the apps can
-- word and draw the job without looking the id up.
create or replace function public.booking_json(p_booking_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select to_jsonb(b) - 'point'
    || jsonb_build_object(
         'order_ref', (select o.ref from public.orders o where o.id = b.order_id),
         'job_code', case when b.buyer_id = auth.uid() then (select c.code from public.booking_codes c where c.booking_id = b.id) end,
         'job_code_locked', (select c.locked_at is not null from public.booking_codes c where c.booking_id = b.id),
         'technician', (select jsonb_build_object(
                          'id', t.id, 'name', tp.display_name, 'avatar_key', t.avatar_key, 'verified', t.verified,
                          'rating_avg', t.rating_avg, 'rating_count', t.rating_count,
                          'phone', case when b.status in ('ACCEPTED', 'EN_ROUTE', 'IN_PROGRESS') or auth.uid() <> b.buyer_id
                                        then tp.phone end)
                        from public.technicians t join public.profiles tp on tp.id = t.user_id where t.id = b.technician_id),
         'buyer', case when auth.uid() <> b.buyer_id then (
                    select jsonb_build_object('name', bp.display_name, 'phone', bp.phone)
                    from public.profiles bp where bp.id = b.buyer_id) end,
         'bay', (select jsonb_build_object('shop_id', s.id, 'name_ar', s.name_ar, 'name_en', s.name_en,
                                           'plot_no', s.plot_no, 'zone_id', s.zone_id, 'lat', s.lat, 'lng', s.lng)
                 from public.shops s where s.id = b.bay_shop_id),
         'items', coalesce((select jsonb_agg(to_jsonb(i) - 'booking_id'
                                             || jsonb_build_object('job_type_code', jt.code) order by i.title_ar)
                            from public.booking_items i join public.job_types jt on jt.id = i.job_type_id
                            where i.booking_id = b.id), '[]'),
         'events', coalesce((select jsonb_agg(jsonb_build_object('from', e.from_status, 'to', e.to_status,
                                                                 'actor', e.actor_kind, 'at', e.at, 'reason', e.reason)
                                              order by e.at, e.id)
                             from public.booking_events e where e.booking_id = b.id), '[]'),
         'photos', coalesce((select jsonb_agg(jsonb_build_object('id', ph.id, 'kind', ph.kind, 'image_key', ph.image_key,
                                                                 'taken_at', ph.taken_at) order by ph.taken_at)
                             from public.booking_photos ph where ph.booking_id = b.id), '[]'),
         'offer', (select jsonb_build_object('id', f.id, 'status', f.status, 'expires_at', f.expires_at)
                   from public.booking_offers f where f.booking_id = b.id and f.technician_id = b.technician_id
                   order by f.offered_at desc limit 1),
         'payments', coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'method', p.method, 'purpose', p.purpose,
                                                                   'status', p.status, 'amount_sdg', p.amount_sdg))
                               from public.payments p where p.booking_id = b.id
                                  or (p.order_id = b.order_id and p.method = 'BANKAK')), '[]'))
  from public.bookings b
  where b.id = p_booking_id;
$$;

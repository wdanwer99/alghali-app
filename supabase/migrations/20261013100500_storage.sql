-- M1 storage buckets and policies. Every bucket has a size limit and a MIME allow-list.
--   media-public   listing photos and storefronts: shops/{shop_id}/…; profile photos: users/{uid}/…
--   templates      the Excel import template (admins upload)
--   app-releases   Android APKs for the download page (admins upload, D-058)
--   imports        a shop's uploaded stock sheets: {shop_id}/…
--   receipts, booking-photos, request-photos, voice-notes: private; policies arrive with M2/M3.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('media-public',   'media-public',   true,  5242880,
     array['image/webp', 'image/jpeg', 'image/png']),
  ('templates',      'templates',      true,  5242880,
     array['application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 'text/csv']),
  ('app-releases',   'app-releases',   true,  52428800,
     array['application/vnd.android.package-archive']),
  ('imports',        'imports',        false, 5242880,
     array['application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 'application/vnd.ms-excel', 'text/csv']),
  ('receipts',       'receipts',       false, 5242880,
     array['image/webp', 'image/jpeg', 'image/png', 'application/pdf']),
  ('booking-photos', 'booking-photos', false, 5242880,
     array['image/webp', 'image/jpeg', 'image/png']),
  ('request-photos', 'request-photos', false, 5242880,
     array['image/webp', 'image/jpeg', 'image/png']),
  ('voice-notes',    'voice-notes',    false, 2097152,
     array['audio/mp4', 'audio/m4a', 'audio/x-m4a', 'audio/aac', 'audio/mpeg'])
on conflict (id) do update set
  public             = excluded.public,
  file_size_limit    = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create function public.try_uuid(p text)
returns uuid
language plpgsql
immutable
set search_path = ''
as $$
begin
  return p::uuid;
exception
  when invalid_text_representation then return null;
end
$$;
revoke all on function public.try_uuid(text) from public, anon, authenticated;
grant execute on function public.try_uuid(text) to authenticated;

-- media-public: shop members manage their shop's folder; users manage their own folder.
-- (Reads of a public bucket go through the public URL and need no policy; select is for upserts.)
create policy media_public_select on storage.objects for select to authenticated
  using (bucket_id = 'media-public' and (
    ((storage.foldername(name))[1] = 'shops' and public.is_shop_member(public.try_uuid((storage.foldername(name))[2])))
    or ((storage.foldername(name))[1] = 'users' and (storage.foldername(name))[2] = (select auth.uid())::text)));
create policy media_public_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'media-public' and (
    ((storage.foldername(name))[1] = 'shops' and public.is_shop_member(public.try_uuid((storage.foldername(name))[2])))
    or ((storage.foldername(name))[1] = 'users' and (storage.foldername(name))[2] = (select auth.uid())::text)));
create policy media_public_update on storage.objects for update to authenticated
  using (bucket_id = 'media-public' and (
    ((storage.foldername(name))[1] = 'shops' and public.is_shop_member(public.try_uuid((storage.foldername(name))[2])))
    or ((storage.foldername(name))[1] = 'users' and (storage.foldername(name))[2] = (select auth.uid())::text)));
create policy media_public_delete on storage.objects for delete to authenticated
  using (bucket_id = 'media-public' and (
    ((storage.foldername(name))[1] = 'shops' and public.is_shop_member(public.try_uuid((storage.foldername(name))[2])))
    or ((storage.foldername(name))[1] = 'users' and (storage.foldername(name))[2] = (select auth.uid())::text)));

-- imports: a shop's members upload and read their own sheets.
create policy imports_select on storage.objects for select to authenticated
  using (bucket_id = 'imports' and public.is_shop_member(public.try_uuid((storage.foldername(name))[1])));
create policy imports_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'imports' and public.is_shop_member(public.try_uuid((storage.foldername(name))[1])));

-- templates, app-releases: admins only.
create policy admin_files_select on storage.objects for select to authenticated
  using (bucket_id in ('templates', 'app-releases') and (select public.is_admin()));
create policy admin_files_insert on storage.objects for insert to authenticated
  with check (bucket_id in ('templates', 'app-releases') and (select public.is_admin()));
create policy admin_files_update on storage.objects for update to authenticated
  using (bucket_id in ('templates', 'app-releases') and (select public.is_admin()));
create policy admin_files_delete on storage.objects for delete to authenticated
  using (bucket_id in ('templates', 'app-releases') and (select public.is_admin()));

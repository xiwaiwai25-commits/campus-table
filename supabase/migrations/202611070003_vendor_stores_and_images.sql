alter table public.stores
  add column category_key text not null default 'Other'
  check (category_key in ('Asian', 'Cafe', 'Local', 'Other'));

create or replace function public.create_mealsync_profile()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  chosen_role text := coalesce(new.raw_user_meta_data ->> 'role', 'student');
  chosen_name text := trim(coalesce(new.raw_user_meta_data ->> 'full_name', ''));
  store_name text := trim(coalesce(new.raw_user_meta_data ->> 'store_name', ''));
begin
  if chosen_role not in ('student', 'vendor') then
    raise exception 'Choose student or vendor when registering';
  end if;
  if char_length(chosen_name) not between 1 and 80 then
    raise exception 'Name must be between 1 and 80 characters';
  end if;
  insert into public.profiles(id, full_name, role)
  values (new.id, chosen_name, chosen_role);
  if chosen_role = 'vendor' then
    if char_length(store_name) not between 1 and 100 then
      raise exception 'Vendor registration requires a store name';
    end if;
    insert into public.stores(vendor_id, name, description, category_key, category, image_url)
    values (
      new.id,
      store_name,
      left(coalesce(new.raw_user_meta_data ->> 'store_description', ''), 500),
      case when new.raw_user_meta_data ->> 'store_category' in ('Asian','Cafe','Local')
        then new.raw_user_meta_data ->> 'store_category' else 'Other' end,
      case when new.raw_user_meta_data ->> 'store_category' = 'Asian' then 'Asian comfort'
        when new.raw_user_meta_data ->> 'store_category' = 'Cafe' then 'Coffee & brunch'
        when new.raw_user_meta_data ->> 'store_category' = 'Local' then 'Local favourites'
        else 'Other' end,
      left(coalesce(new.raw_user_meta_data ->> 'store_image', ''), 1000)
    );
  end if;
  return new;
end;
$$;

revoke all on function public.create_mealsync_profile() from public, anon, authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('menu-images', 'menu-images', true, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = true, file_size_limit = 5242880,
  allowed_mime_types = excluded.allowed_mime_types;

create policy mealsync_images_public_read on storage.objects
  for select to anon, authenticated using (bucket_id = 'menu-images');
create policy mealsync_vendor_image_upload on storage.objects
  for insert to authenticated with check (
    bucket_id = 'menu-images' and exists (
      select 1 from public.stores s
      where s.id::text = (storage.foldername(name))[1]
        and s.vendor_id = (select auth.uid())
    )
  );
create policy mealsync_vendor_image_update on storage.objects
  for update to authenticated using (
    bucket_id = 'menu-images' and exists (
      select 1 from public.stores s
      where s.id::text = (storage.foldername(name))[1]
        and s.vendor_id = (select auth.uid())
    )
  ) with check (
    bucket_id = 'menu-images' and exists (
      select 1 from public.stores s
      where s.id::text = (storage.foldername(name))[1]
        and s.vendor_id = (select auth.uid())
    )
  );
create policy mealsync_vendor_image_delete on storage.objects
  for delete to authenticated using (
    bucket_id = 'menu-images' and exists (
      select 1 from public.stores s
      where s.id::text = (storage.foldername(name))[1]
        and s.vendor_id = (select auth.uid())
    )
  );

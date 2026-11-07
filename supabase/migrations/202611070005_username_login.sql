alter table public.profiles
  add column username text not null check (char_length(username) between 3 and 100),
  add column username_key text generated always as (lower(btrim(username))) stored unique,
  add column email text not null unique;

create or replace function public.protect_profile_role()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.id <> old.id or new.role <> old.role
     or new.username <> old.username or new.email <> old.email then
    raise exception 'Account identity and role cannot be changed here';
  end if;
  new.updated_at := now();
  return new;
end;
$$;

create or replace function public.create_mealsync_profile()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  chosen_role text := coalesce(new.raw_user_meta_data ->> 'role', 'student');
  chosen_name text := trim(coalesce(new.raw_user_meta_data ->> 'full_name', ''));
  store_name text := trim(coalesce(new.raw_user_meta_data ->> 'store_name', ''));
  chosen_username text := trim(coalesce(new.raw_user_meta_data ->> 'username', ''));
begin
  if chosen_role not in ('student', 'vendor') then
    raise exception 'Choose student or vendor when registering';
  end if;
  if char_length(chosen_name) not between 1 and 80 then
    raise exception 'Name must be between 1 and 80 characters';
  end if;
  if char_length(chosen_username) not between 3 and 100 then
    raise exception 'Username must be between 3 and 100 characters';
  end if;
  if chosen_role = 'student' and chosen_username !~* '^TP[0-9]{6,10}$' then
    raise exception 'Student username must be a valid TP number';
  end if;
  insert into public.profiles(id, full_name, role, username, email)
  values (new.id, chosen_name, chosen_role, chosen_username, lower(new.email));
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
grant select (id, full_name, role, username, email, created_at)
  on public.profiles to authenticated;

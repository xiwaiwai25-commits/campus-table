-- Keep TP identifiers separate from public login names.
alter table public.profiles add column if not exists tp_number text;

update public.profiles
set tp_number = upper(username)
where role = 'student'
  and tp_number is null
  and username ~* '^TP[0-9]{6}$';

alter table public.profiles
  add constraint profiles_tp_number_format_check
  check (tp_number is null or tp_number ~ '^TP[0-9]{6}$');

create unique index profiles_tp_number_unique
  on public.profiles(tp_number)
  where tp_number is not null;

grant select (tp_number) on public.profiles to authenticated;

create or replace function public.create_mealsync_profile()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  chosen_role text := coalesce(new.raw_user_meta_data ->> 'role', 'student');
  chosen_name text := trim(coalesce(new.raw_user_meta_data ->> 'full_name', ''));
  store_name text := trim(coalesce(new.raw_user_meta_data ->> 'store_name', ''));
  chosen_username text := trim(coalesce(new.raw_user_meta_data ->> 'username', ''));
  chosen_tp text := upper(trim(coalesce(new.raw_user_meta_data ->> 'tp_number', '')));
  store_category text := coalesce(new.raw_user_meta_data ->> 'store_category', 'Other');
begin
  if chosen_role not in ('student', 'vendor') then
    raise exception 'Choose student or vendor when registering';
  end if;
  if char_length(chosen_name) not between 1 and 80 then
    raise exception 'Name must be between 1 and 80 characters';
  end if;
  if char_length(chosen_username) not between 3 and 32
     or chosen_username !~ '^[A-Za-z0-9][A-Za-z0-9._-]*[A-Za-z0-9]$' then
    raise exception 'Username must be 3 to 32 letters, numbers, dots, hyphens or underscores';
  end if;
  if chosen_role = 'student' and chosen_tp !~ '^TP[0-9]{6}$' then
    raise exception 'Student TP number must look like TP089876';
  end if;
  if chosen_role = 'vendor' and char_length(store_name) not between 1 and 100 then
    raise exception 'Vendor registration requires a store name';
  end if;
  if store_category not in ('Asian', 'Cafe', 'Local', 'Other') then
    store_category := 'Other';
  end if;

  insert into public.profiles(id, full_name, role, username, email, tp_number)
  values (
    new.id,
    chosen_name,
    chosen_role,
    chosen_username,
    lower(new.email),
    case when chosen_role = 'student' then chosen_tp else null end
  );

  if chosen_role = 'vendor' then
    insert into public.stores(vendor_id, name, description, category_key, category, image_url)
    values (
      new.id,
      store_name,
      left(coalesce(new.raw_user_meta_data ->> 'store_description', ''), 500),
      store_category,
      case when store_category = 'Asian' then 'Asian comfort'
        when store_category = 'Cafe' then 'Coffee & brunch'
        when store_category = 'Local' then 'Local favourites'
        else 'Other' end,
      left(coalesce(new.raw_user_meta_data ->> 'store_image', ''), 1000)
    );
  end if;
  return new;
end;
$$;

revoke all on function public.create_mealsync_profile() from public, anon, authenticated;

create or replace function public.demo_save_product(
  p_store_id uuid,
  p_product_id uuid,
  p_name text,
  p_description text,
  p_price numeric,
  p_image_url text default '',
  p_is_available boolean default true
)
returns public.demo_products
language plpgsql security definer set search_path = '' as $$
declare
  saved public.demo_products%rowtype;
  clean_image text := trim(coalesce(p_image_url, ''));
begin
  if not exists(select 1 from public.demo_stores where id = p_store_id) then
    raise exception 'Demo stall not found';
  end if;
  if char_length(trim(coalesce(p_name, ''))) not between 1 and 100 then
    raise exception 'Item name must be between 1 and 100 characters';
  end if;
  if char_length(coalesce(p_description, '')) > 500 then
    raise exception 'Description is too long';
  end if;
  if p_price is null or p_price < 0 or p_price > 99999 then
    raise exception 'Enter a valid item price';
  end if;
  if clean_image <> '' and clean_image !~* '^https?://' then
    raise exception 'Photo URL must start with http:// or https://';
  end if;

  if p_product_id is null then
    insert into public.demo_products(id, store_id, name, description, price, image_url, is_available)
    values(gen_random_uuid(), p_store_id, trim(p_name), coalesce(trim(p_description), ''), p_price, clean_image, coalesce(p_is_available, true))
    returning * into saved;
  else
    update public.demo_products
       set name = trim(p_name),
           description = coalesce(trim(p_description), ''),
           price = p_price,
           image_url = clean_image,
           is_available = coalesce(p_is_available, true)
     where id = p_product_id and store_id = p_store_id
     returning * into saved;
    if not found then raise exception 'Demo menu item not found'; end if;
  end if;
  return saved;
end;
$$;

create or replace function public.demo_reset()
returns void language plpgsql security definer set search_path = '' as $$
begin
  delete from public.demo_orders;
  delete from public.demo_products where id not in (
    '20000000-0000-4000-8000-000000000001'::uuid,
    '20000000-0000-4000-8000-000000000002'::uuid,
    '20000000-0000-4000-8000-000000000003'::uuid,
    '20000000-0000-4000-8000-000000000004'::uuid,
    '20000000-0000-4000-8000-000000000005'::uuid,
    '20000000-0000-4000-8000-000000000006'::uuid,
    '20000000-0000-4000-8000-000000000007'::uuid,
    '20000000-0000-4000-8000-000000000008'::uuid
  );

  insert into public.demo_products(id, store_id, name, description, price, image_url, is_available)
  values
    ('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','Sesame chicken noodles','Ginger soy chicken, greens and springy noodles.',13.90,'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?auto=format&fit=crop&w=700&q=80',true),
    ('20000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','Crispy tofu bowl','Crispy tofu, rice and a bright sesame dressing.',11.50,'https://images.unsplash.com/photo-1547592180-85f173990554?auto=format&fit=crop&w=700&q=80',true),
    ('20000000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000002','Iced oat latte','Double espresso over chilled oat milk.',12.00,'https://images.unsplash.com/photo-1461023058943-07fcbe16d735?auto=format&fit=crop&w=700&q=80',true),
    ('20000000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000002','Avocado toast','Sourdough, smashed avocado and lemon.',16.50,'https://images.unsplash.com/photo-1525351484163-7529414344d8?auto=format&fit=crop&w=700&q=80',true),
    ('20000000-0000-4000-8000-000000000005','10000000-0000-4000-8000-000000000003','Nasi lemak ayam','Coconut rice, sambal, egg and crispy chicken.',14.90,'https://images.unsplash.com/photo-1512058564366-18510be2db19?auto=format&fit=crop&w=700&q=80',true),
    ('20000000-0000-4000-8000-000000000006','10000000-0000-4000-8000-000000000003','Curry laksa','Rich coconut broth, noodles and fresh herbs.',13.50,'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?auto=format&fit=crop&w=700&q=80',true),
    ('20000000-0000-4000-8000-000000000007','10000000-0000-4000-8000-000000000004','Brown sugar pearl milk tea','Fresh milk tea with chewy brown sugar pearls.',10.90,'https://images.unsplash.com/photo-1556679343-c7306c1976bc?auto=format&fit=crop&w=700&q=80',true),
    ('20000000-0000-4000-8000-000000000008','10000000-0000-4000-8000-000000000004','Peach jasmine tea','Jasmine tea, peach and a little citrus.',9.50,'https://images.unsplash.com/photo-1544145945-f90425340c7e?auto=format&fit=crop&w=700&q=80',true)
  on conflict (id) do update set
    store_id = excluded.store_id,
    name = excluded.name,
    description = excluded.description,
    price = excluded.price,
    image_url = excluded.image_url,
    is_available = true;
end;
$$;

revoke all on function public.demo_save_product(uuid, uuid, text, text, numeric, text, boolean) from public;
revoke all on function public.demo_reset() from public;
grant execute on function public.demo_save_product(uuid, uuid, text, text, numeric, text, boolean) to anon, authenticated;
grant execute on function public.demo_reset() to anon, authenticated;

do $$ begin
  alter publication supabase_realtime add table public.demo_products;
exception when duplicate_object then null;
end $$;

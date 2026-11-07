-- MealSync core schema. Every user-owned write is guarded by RLS or an RPC.
create extension if not exists pgcrypto;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null check (char_length(full_name) between 1 and 80),
  role text not null check (role in ('student', 'vendor')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.stores (
  id uuid primary key default gen_random_uuid(),
  vendor_id uuid unique references public.profiles(id) on delete set null,
  name text not null check (char_length(name) between 1 and 100),
  description text not null default '' check (char_length(description) <= 500),
  category text not null default 'Other',
  image_url text not null default '',
  is_open boolean not null default true,
  prep_minutes integer not null default 20 check (prep_minutes between 5 and 180),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.products (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 100),
  description text not null default '' check (char_length(description) <= 500),
  price numeric(10,2) not null check (price >= 0),
  image_url text not null default '',
  is_available boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete restrict,
  student_id uuid references public.profiles(id) on delete set null,
  student_name_snapshot text not null,
  status text not null default 'pending'
    check (status in ('pending','accepted','preparing','ready','completed','rejected','cancelled')),
  eta_minutes integer not null default 20 check (eta_minutes between 5 and 180),
  note text not null default '' check (char_length(note) <= 500),
  decline_reason text not null default '' check (char_length(decline_reason) <= 500),
  total numeric(10,2) not null default 0 check (total >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  name_snapshot text not null,
  unit_price numeric(10,2) not null check (unit_price >= 0),
  quantity integer not null check (quantity between 1 and 99)
);

create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references public.orders(id) on delete cascade,
  store_id uuid not null references public.stores(id) on delete cascade,
  student_id uuid references public.profiles(id) on delete set null,
  is_anonymous boolean not null default true,
  rating integer not null check (rating between 1 and 5),
  tags text[] not null default '{}',
  comment text not null default '' check (char_length(comment) <= 1000),
  reply text not null default '' check (char_length(reply) <= 1000),
  created_at timestamptz not null default now()
);

create index products_store_idx on public.products(store_id);
create index orders_student_created_idx on public.orders(student_id, created_at desc);
create index orders_store_created_idx on public.orders(store_id, created_at desc);
create index order_items_order_idx on public.order_items(order_id);
create index reviews_store_created_idx on public.reviews(store_id, created_at desc);

alter table public.profiles enable row level security;
alter table public.stores enable row level security;
alter table public.products enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.reviews enable row level security;

create or replace function public.create_mealsync_profile()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  chosen_role text := coalesce(new.raw_user_meta_data ->> 'role', 'student');
  chosen_name text := trim(coalesce(new.raw_user_meta_data ->> 'full_name', ''));
begin
  if chosen_role not in ('student', 'vendor') then
    raise exception 'Choose student or vendor when registering';
  end if;
  if char_length(chosen_name) not between 1 and 80 then
    raise exception 'Name must be between 1 and 80 characters';
  end if;
  insert into public.profiles(id, full_name, role)
  values (new.id, chosen_name, chosen_role);
  return new;
end;
$$;

create trigger mealsync_auth_user_created
  after insert on auth.users
  for each row execute function public.create_mealsync_profile();

create or replace function public.protect_profile_role()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.id <> old.id or new.role <> old.role then
    raise exception 'Account identity and role cannot be changed';
  end if;
  new.updated_at := now();
  return new;
end;
$$;

-- Keep account deletion recoverable in reports while anonymizing student details.
create or replace function public.archive_profile_data()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  update public.orders set student_name_snapshot = 'Anonymous'
    where student_id = old.id;
  update public.reviews set is_anonymous = true
    where student_id = old.id;
  if old.role = 'vendor' then
    update public.stores set is_open = false, vendor_id = null
      where vendor_id = old.id;
  end if;
  return old;
end;
$$;

create trigger mealsync_profile_role_guard
  before update on public.profiles
  for each row execute function public.protect_profile_role();
create trigger mealsync_profile_archive
  before delete on public.profiles
  for each row execute function public.archive_profile_data();

create or replace function public.touch_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end;
$$;
create trigger stores_touch_updated_at before update on public.stores
  for each row execute function public.touch_updated_at();
create trigger products_touch_updated_at before update on public.products
  for each row execute function public.touch_updated_at();
create trigger orders_touch_updated_at before update on public.orders
  for each row execute function public.touch_updated_at();

create policy profiles_read_self on public.profiles
  for select to authenticated using (id = (select auth.uid()));
create policy stores_public_read on public.stores
  for select to anon, authenticated using (true);
create policy stores_insert_own on public.stores
  for insert to authenticated with check (
    vendor_id = (select auth.uid()) and exists (
      select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'vendor'
    )
  );
create policy stores_update_own on public.stores
  for update to authenticated using (vendor_id = (select auth.uid()))
  with check (vendor_id = (select auth.uid()));
create policy products_public_read on public.products
  for select to anon, authenticated using (true);
create policy products_insert_own_store on public.products
  for insert to authenticated with check (exists (
    select 1 from public.stores s where s.id = store_id and s.vendor_id = (select auth.uid())
  ));
create policy products_update_own_store on public.products
  for update to authenticated using (exists (
    select 1 from public.stores s where s.id = store_id and s.vendor_id = (select auth.uid())
  )) with check (exists (
    select 1 from public.stores s where s.id = store_id and s.vendor_id = (select auth.uid())
  ));
create policy products_delete_own_store on public.products
  for delete to authenticated using (exists (
    select 1 from public.stores s where s.id = store_id and s.vendor_id = (select auth.uid())
  ));
create policy orders_read_participant on public.orders
  for select to authenticated using (
    student_id = (select auth.uid()) or exists (
      select 1 from public.stores s where s.id = store_id and s.vendor_id = (select auth.uid())
    )
  );
create policy order_items_read_participant on public.order_items
  for select to authenticated using (exists (
    select 1 from public.orders o where o.id = order_id and (
      o.student_id = (select auth.uid()) or exists (
        select 1 from public.stores s where s.id = o.store_id and s.vendor_id = (select auth.uid())
      )
    )
  ));
create policy reviews_public_read on public.reviews
  for select to anon, authenticated using (true);
create policy reviews_vendor_reply on public.reviews
  for update to authenticated using (exists (
    select 1 from public.stores s where s.id = store_id and s.vendor_id = (select auth.uid())
  )) with check (exists (
    select 1 from public.stores s where s.id = store_id and s.vendor_id = (select auth.uid())
  ));

revoke all on public.profiles, public.stores, public.products, public.orders,
  public.order_items, public.reviews from anon, authenticated;
grant select on public.stores, public.products to anon, authenticated;
grant insert, update on public.stores to authenticated;
grant insert, update, delete on public.products to authenticated;
grant select on public.orders, public.order_items to authenticated;
grant select (id, store_id, is_anonymous, rating, tags, comment, reply, created_at)
  on public.reviews to anon, authenticated;
grant update (reply) on public.reviews to authenticated;
grant select (id, full_name, role, created_at) on public.profiles to authenticated;
grant update (full_name) on public.profiles to authenticated;

create or replace function public.place_order(
  p_store_id uuid, p_items jsonb, p_note text default ''
) returns uuid language plpgsql security definer set search_path = '' as $$
declare
  new_order_id uuid;
  profile_name text;
  row_item jsonb;
  product_row public.products%rowtype;
  qty integer;
  order_total numeric(10,2) := 0;
begin
  if (select p.role from public.profiles p where p.id = (select auth.uid())) <> 'student' then
    raise exception 'Only student accounts can place orders';
  end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'Add at least one item to the order';
  end if;
  if char_length(coalesce(p_note, '')) > 500 then raise exception 'Order note is too long'; end if;
  select p.full_name into profile_name from public.profiles p where p.id = (select auth.uid());
  if not exists (select 1 from public.stores s where s.id = p_store_id and s.is_open) then
    raise exception 'This stall is currently closed';
  end if;
  insert into public.orders(store_id, student_id, student_name_snapshot, note)
  values (p_store_id, (select auth.uid()), profile_name, coalesce(p_note, ''))
  returning id into new_order_id;
  for row_item in select value from jsonb_array_elements(p_items) loop
    qty := (row_item ->> 'quantity')::integer;
    if qty not between 1 and 99 then raise exception 'Invalid item quantity'; end if;
    select * into product_row from public.products p
      where p.id = (row_item ->> 'product_id')::uuid
        and p.store_id = p_store_id and p.is_available for update;
    if not found then raise exception 'An item is unavailable; refresh the menu'; end if;
    insert into public.order_items(order_id, product_id, name_snapshot, unit_price, quantity)
    values (new_order_id, product_row.id, product_row.name, product_row.price, qty);
    order_total := order_total + product_row.price * qty;
  end loop;
  update public.orders set total = order_total where id = new_order_id;
  return new_order_id;
end;
$$;

create or replace function public.change_order(
  p_order_id uuid, p_action text, p_eta_minutes integer default null,
  p_reason text default ''
) returns public.orders language plpgsql security definer set search_path = '' as $$
declare
  order_row public.orders%rowtype;
  account_role text;
  vendor_owns boolean;
begin
  select p.role into account_role from public.profiles p where p.id = (select auth.uid());
  select o.* into order_row from public.orders o where o.id = p_order_id for update;
  if not found then raise exception 'Order not found'; end if;
  select exists (select 1 from public.stores s
    where s.id = order_row.store_id and s.vendor_id = (select auth.uid())) into vendor_owns;

  if account_role = 'vendor' and vendor_owns then
    if order_row.status = 'pending' and p_action = 'accept' then
      update public.orders set status = 'accepted',
        eta_minutes = coalesce(p_eta_minutes, 20), decline_reason = ''
        where id = p_order_id returning * into order_row;
    elsif order_row.status = 'pending' and p_action = 'reject' then
      if char_length(trim(coalesce(p_reason, ''))) = 0 then raise exception 'A decline reason is required'; end if;
      update public.orders set status = 'rejected', decline_reason = left(trim(p_reason), 500)
        where id = p_order_id returning * into order_row;
    elsif order_row.status = 'accepted' and p_action = 'preparing' then
      update public.orders set status = 'preparing' where id = p_order_id returning * into order_row;
    elsif order_row.status = 'preparing' and p_action = 'ready' then
      update public.orders set status = 'ready' where id = p_order_id returning * into order_row;
    elsif order_row.status = 'ready' and p_action = 'complete' then
      update public.orders set status = 'completed' where id = p_order_id returning * into order_row;
    else raise exception 'This order status cannot be changed to that state';
    end if;
  elsif account_role = 'student' and order_row.student_id = (select auth.uid()) and p_action = 'cancel' then
    if order_row.status = 'pending' or (order_row.status = 'accepted' and order_row.eta_minutes > 60) then
      update public.orders set status = 'cancelled' where id = p_order_id returning * into order_row;
    else raise exception 'This order can no longer be cancelled';
    end if;
  else raise exception 'You do not have permission to update this order';
  end if;
  if p_action = 'accept' and coalesce(p_eta_minutes, 20) not between 5 and 180 then
    raise exception 'Preparation estimate must be between 5 and 180 minutes';
  end if;
  return order_row;
end;
$$;

create or replace function public.submit_review(
  p_order_id uuid, p_rating integer, p_tags text[] default '{}',
  p_comment text default '', p_anonymous boolean default true
) returns uuid language plpgsql security definer set search_path = '' as $$
declare
  order_row public.orders%rowtype;
  review_id uuid;
begin
  if (select p.role from public.profiles p where p.id = (select auth.uid())) <> 'student' then
    raise exception 'Only student accounts can post reviews';
  end if;
  if p_rating not between 1 and 5 or char_length(coalesce(p_comment, '')) > 1000 then
    raise exception 'Invalid review';
  end if;
  select o.* into order_row from public.orders o
    where o.id = p_order_id and o.student_id = (select auth.uid()) and o.status = 'completed';
  if not found then raise exception 'Only completed orders can be reviewed'; end if;
  insert into public.reviews(order_id, store_id, student_id, is_anonymous, rating, tags, comment)
    values (p_order_id, order_row.store_id, (select auth.uid()), coalesce(p_anonymous, true),
      p_rating, coalesce(p_tags, '{}'), coalesce(p_comment, '')) returning id into review_id;
  return review_id;
end;
$$;

create or replace function public.reply_to_review(p_review_id uuid, p_reply text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if (select p.role from public.profiles p where p.id = (select auth.uid())) <> 'vendor'
     or not exists (
       select 1 from public.reviews r join public.stores s on s.id = r.store_id
       where r.id = p_review_id and s.vendor_id = (select auth.uid())
     ) then raise exception 'You do not have permission to reply to this review'; end if;
  if char_length(coalesce(p_reply, '')) not between 1 and 1000 then
    raise exception 'Reply must be between 1 and 1000 characters';
  end if;
  update public.reviews set reply = trim(p_reply) where id = p_review_id;
end;
$$;

revoke all on function public.place_order(uuid, jsonb, text) from public, anon;
revoke all on function public.change_order(uuid, text, integer, text) from public, anon;
revoke all on function public.submit_review(uuid, integer, text[], text, boolean) from public, anon;
revoke all on function public.reply_to_review(uuid, text) from public, anon;
grant execute on function public.place_order(uuid, jsonb, text) to authenticated;
grant execute on function public.change_order(uuid, text, integer, text) to authenticated;
grant execute on function public.submit_review(uuid, integer, text[], text, boolean) to authenticated;
grant execute on function public.reply_to_review(uuid, text) to authenticated;

do $$ begin
  alter publication supabase_realtime add table public.orders;
exception when duplicate_object then null;
end $$;

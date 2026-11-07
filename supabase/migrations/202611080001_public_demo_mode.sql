-- Isolated, public demo data. These rows never enter real MealSync tables.
create table if not exists public.demo_stores (
  id uuid primary key,
  name text not null,
  category text not null,
  category_key text not null,
  description text not null default '',
  rating numeric(2,1) not null default 0,
  prep_minutes integer not null default 20,
  image_url text not null default '',
  is_open boolean not null default true
);

create table if not exists public.demo_products (
  id uuid primary key,
  store_id uuid not null references public.demo_stores(id) on delete cascade,
  name text not null,
  description text not null default '',
  price numeric(10,2) not null check (price >= 0),
  image_url text not null default '',
  is_available boolean not null default true
);

create table if not exists public.demo_orders (
  id bigint generated always as identity primary key,
  store_id uuid not null references public.demo_stores(id),
  student_label text not null default 'Sample Student',
  items jsonb not null,
  total numeric(10,2) not null check (total >= 0),
  note text not null default '',
  status text not null default 'pending'
    check (status in ('pending','accepted','preparing','ready','completed','cancelled','rejected')),
  eta_minutes integer,
  decline_reason text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.demo_stores(id,name,category,category_key,description,rating,prep_minutes,image_url) values
('10000000-0000-4000-8000-000000000001','Nook & Noodle','Asian comfort','Asian','Warm bowls, hand-pulled noodles and comforting favourites.',4.8,20,'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?auto=format&fit=crop&w=900&q=80'),
('10000000-0000-4000-8000-000000000002','Little Leaf Café','Coffee & brunch','Cafe','Coffee, sandwiches and a quiet moment between classes.',4.7,15,'https://images.unsplash.com/photo-1461023058943-07fcbe16d735?auto=format&fit=crop&w=900&q=80'),
('10000000-0000-4000-8000-000000000003','Kampung Table','Local favourites','Local','Familiar Malaysian flavours, cooked fresh every day.',4.9,25,'https://images.unsplash.com/photo-1512058564366-18510be2db19?auto=format&fit=crop&w=900&q=80'),
('10000000-0000-4000-8000-000000000004','Pearl & Petal','Drinks & treats','Cafe','Milk tea, fruit tea and little treats for a study break.',4.6,10,'https://images.unsplash.com/photo-1556679343-c7306c1976bc?auto=format&fit=crop&w=900&q=80')
on conflict (id) do nothing;

insert into public.demo_products(id,store_id,name,description,price,image_url) values
('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','Sesame chicken noodles','Ginger soy chicken, greens and springy noodles.',13.90,'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?auto=format&fit=crop&w=700&q=80'),
('20000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','Crispy tofu bowl','Crispy tofu, rice and a bright sesame dressing.',11.50,'https://images.unsplash.com/photo-1547592180-85f173990554?auto=format&fit=crop&w=700&q=80'),
('20000000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000002','Iced oat latte','Double espresso over chilled oat milk.',12.00,'https://images.unsplash.com/photo-1461023058943-07fcbe16d735?auto=format&fit=crop&w=700&q=80'),
('20000000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000002','Avocado toast','Sourdough, smashed avocado and lemon.',16.50,'https://images.unsplash.com/photo-1525351484163-7529414344d8?auto=format&fit=crop&w=700&q=80'),
('20000000-0000-4000-8000-000000000005','10000000-0000-4000-8000-000000000003','Nasi lemak ayam','Coconut rice, sambal, egg and crispy chicken.',14.90,'https://images.unsplash.com/photo-1512058564366-18510be2db19?auto=format&fit=crop&w=700&q=80'),
('20000000-0000-4000-8000-000000000006','10000000-0000-4000-8000-000000000003','Curry laksa','Rich coconut broth, noodles and fresh herbs.',13.50,'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?auto=format&fit=crop&w=700&q=80'),
('20000000-0000-4000-8000-000000000007','10000000-0000-4000-8000-000000000004','Brown sugar pearl milk tea','Fresh milk tea with chewy brown sugar pearls.',10.90,'https://images.unsplash.com/photo-1556679343-c7306c1976bc?auto=format&fit=crop&w=700&q=80'),
('20000000-0000-4000-8000-000000000008','10000000-0000-4000-8000-000000000004','Peach jasmine tea','Jasmine tea, peach and a little citrus.',9.50,'https://images.unsplash.com/photo-1544145945-f90425340c7e?auto=format&fit=crop&w=700&q=80')
on conflict (id) do nothing;

alter table public.demo_stores enable row level security;
alter table public.demo_products enable row level security;
alter table public.demo_orders enable row level security;
create policy demo_stores_public_read on public.demo_stores for select to anon, authenticated using (true);
create policy demo_products_public_read on public.demo_products for select to anon, authenticated using (true);
create policy demo_orders_public_read on public.demo_orders for select to anon, authenticated using (true);
grant select on public.demo_stores, public.demo_products, public.demo_orders to anon, authenticated;

create or replace function public.demo_place_order(p_store_id uuid,p_items jsonb,p_note text default '')
returns public.demo_orders language plpgsql security definer set search_path = '' as $$
declare
  new_id bigint;
  row_item jsonb;
  product_row public.demo_products%rowtype;
  qty integer;
  amount numeric(10,2) := 0;
  snapshots jsonb := '[]'::jsonb;
begin
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) not between 1 and 20 then
    raise exception 'Add between 1 and 20 demo items';
  end if;
  if char_length(coalesce(p_note,'')) > 500 then raise exception 'Order note is too long'; end if;
  if not exists(select 1 from public.demo_stores where id=p_store_id and is_open) then
    raise exception 'Demo stall is closed';
  end if;
  for row_item in select value from jsonb_array_elements(p_items) loop
    qty := (row_item->>'quantity')::integer;
    if qty not between 1 and 20 then raise exception 'Invalid quantity'; end if;
    select * into product_row from public.demo_products
      where id=(row_item->>'product_id')::uuid and store_id=p_store_id and is_available for update;
    if not found then raise exception 'A demo item is unavailable'; end if;
    amount := amount + product_row.price * qty;
    snapshots := snapshots || jsonb_build_array(jsonb_build_object(
      'product_id',product_row.id,'name',product_row.name,'price',product_row.price,'quantity',qty));
  end loop;
  insert into public.demo_orders(store_id,items,total,note)
    values(p_store_id,snapshots,amount,coalesce(p_note,'')) returning id into new_id;
  return (select o from public.demo_orders o where o.id=new_id);
end;
$$;

create or replace function public.demo_change_order(p_order_id bigint,p_action text,p_eta_minutes integer default null,p_reason text default '')
returns public.demo_orders language plpgsql security definer set search_path = '' as $$
declare o public.demo_orders%rowtype;
begin
  select * into o from public.demo_orders where id=p_order_id for update;
  if not found then raise exception 'Demo order not found'; end if;
  if o.status='pending' and p_action='accept' then
    if coalesce(p_eta_minutes,20) not between 5 and 180 then raise exception 'Enter 5 to 180 minutes'; end if;
    update public.demo_orders set status='accepted',eta_minutes=coalesce(p_eta_minutes,20) where id=p_order_id returning * into o;
  elsif o.status='pending' and p_action='reject' then
    if char_length(trim(coalesce(p_reason,''))) not between 1 and 500 then raise exception 'Add a short reason'; end if;
    update public.demo_orders set status='rejected',decline_reason=trim(p_reason) where id=p_order_id returning * into o;
  elsif o.status='pending' and p_action='cancel' then
    update public.demo_orders set status='cancelled' where id=p_order_id returning * into o;
  elsif o.status='accepted' and p_action='cancel' and o.eta_minutes>60 then
    update public.demo_orders set status='cancelled' where id=p_order_id returning * into o;
  elsif o.status='accepted' and p_action='preparing' then
    update public.demo_orders set status='preparing' where id=p_order_id returning * into o;
  elsif o.status='preparing' and p_action='ready' then
    update public.demo_orders set status='ready' where id=p_order_id returning * into o;
  elsif o.status='ready' and p_action in ('complete','completed') then
    update public.demo_orders set status='completed' where id=p_order_id returning * into o;
  else raise exception 'This demo order cannot be changed to that state';
  end if;
  return o;
end;
$$;

revoke all on function public.demo_place_order(uuid,jsonb,text) from public;
revoke all on function public.demo_change_order(bigint,text,integer,text) from public;
grant execute on function public.demo_place_order(uuid,jsonb,text) to anon, authenticated;
grant execute on function public.demo_change_order(bigint,text,integer,text) to anon, authenticated;
do $$ begin
  alter publication supabase_realtime add table public.demo_orders;
exception when duplicate_object then null;
end $$;

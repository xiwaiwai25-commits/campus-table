-- Add an isolated Demo schedule; real merchant schedules remain in public.stores.
alter table public.demo_stores
  add column if not exists opening_hours jsonb not null default '{}'::jsonb;

alter table public.demo_stores
  drop constraint if exists demo_stores_opening_hours_valid;
alter table public.demo_stores
  add constraint demo_stores_opening_hours_valid
  check (public.valid_store_opening_hours(opening_hours));

create or replace function public.demo_save_store(
  p_store_id uuid,
  p_is_open boolean,
  p_opening_hours jsonb
)
returns public.demo_stores
language plpgsql security definer set search_path = '' as $$
declare
  saved public.demo_stores%rowtype;
begin
  if p_is_open is null then raise exception 'Choose whether the Demo stall is accepting orders'; end if;
  if not public.valid_store_opening_hours(p_opening_hours) then
    raise exception 'Opening hours are invalid';
  end if;
  update public.demo_stores
     set is_open = p_is_open,
         opening_hours = p_opening_hours
   where id = p_store_id
   returning * into saved;
  if not found then raise exception 'Demo stall not found'; end if;
  return saved;
end;
$$;
revoke all on function public.demo_save_store(uuid,boolean,jsonb) from public;
grant execute on function public.demo_save_store(uuid,boolean,jsonb) to anon, authenticated;

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
  if not exists(
    select 1 from public.demo_stores s
    where s.id = p_store_id
      and public.store_is_accepting_orders(s.is_open, s.opening_hours, now())
  ) then
    raise exception 'Demo stall is closed or outside opening hours';
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

create or replace function public.demo_reset()
returns void language plpgsql security definer set search_path = '' as $$
begin
  update public.demo_stores set is_open = true, opening_hours = '{}'::jsonb where true;
  delete from public.demo_orders where true;
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

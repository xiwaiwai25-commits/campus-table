-- Weekly vendor hours and optional text for Demo reviews.
alter table public.stores add column if not exists opening_hours jsonb not null default '{}'::jsonb;

create or replace function public.valid_store_opening_hours(p_hours jsonb)
returns boolean language plpgsql immutable set search_path = '' as $$
declare
  row_item record;
  opens time;
  closes time;
begin
  if p_hours is null or jsonb_typeof(p_hours) <> 'object' then return false; end if;
  for row_item in select key, value from jsonb_each(p_hours) loop
    if row_item.key not in ('mon','tue','wed','thu','fri','sat','sun')
       or jsonb_typeof(row_item.value) <> 'object' then return false; end if;
    if coalesce((row_item.value->>'closed')::boolean, false) then continue; end if;
    if coalesce(row_item.value->>'opens','') !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
       or coalesce(row_item.value->>'closes','') !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' then return false; end if;
    opens := (row_item.value->>'opens')::time;
    closes := (row_item.value->>'closes')::time;
    if opens >= closes then return false; end if;
  end loop;
  return true;
exception when others then return false;
end;
$$;

alter table public.stores drop constraint if exists stores_opening_hours_valid;
alter table public.stores add constraint stores_opening_hours_valid
  check (public.valid_store_opening_hours(opening_hours));

create or replace function public.store_is_accepting_orders(
  p_is_open boolean, p_hours jsonb, p_at timestamptz default now()
) returns boolean language plpgsql stable set search_path = '' as $$
declare
  local_time time;
  weekday_key text;
  day_hours jsonb;
begin
  if not coalesce(p_is_open, false) then return false; end if;
  if p_hours is null or p_hours = '{}'::jsonb then return true; end if;
  local_time := (p_at at time zone 'Asia/Kuala_Lumpur')::time;
  weekday_key := (array['mon','tue','wed','thu','fri','sat','sun'])[
    extract(isodow from (p_at at time zone 'Asia/Kuala_Lumpur'))::integer
  ];
  day_hours := p_hours->weekday_key;
  if day_hours is null or coalesce((day_hours->>'closed')::boolean, false) then return false; end if;
  return local_time >= (day_hours->>'opens')::time and local_time < (day_hours->>'closes')::time;
exception when others then return false;
end;
$$;
revoke all on function public.valid_store_opening_hours(jsonb) from public, anon, authenticated;
revoke all on function public.store_is_accepting_orders(boolean,jsonb,timestamptz) from public, anon, authenticated;

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
  if not exists (
    select 1 from public.stores s where s.id = p_store_id
      and public.store_is_accepting_orders(s.is_open, s.opening_hours, now())
  ) then raise exception 'This stall is currently closed or not accepting orders'; end if;
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

alter table public.demo_reviews drop constraint if exists demo_reviews_comment_check;
alter table public.demo_reviews add constraint demo_reviews_comment_check
  check (char_length(comment) between 0 and 1000);

create or replace function public.demo_submit_review(
  p_order_id bigint, p_rating integer, p_tags text[] default '{}', p_comment text default ''
) returns public.demo_reviews language plpgsql security definer set search_path = '' as $$
declare
  order_row public.demo_orders%rowtype;
  saved public.demo_reviews%rowtype;
  clean_comment text := trim(coalesce(p_comment, ''));
begin
  if p_rating not between 1 and 5 then raise exception 'Choose a rating from 1 to 5'; end if;
  if char_length(clean_comment) > 1000 then raise exception 'Comment must be 1000 characters or fewer'; end if;
  if coalesce(cardinality(p_tags), 0) > 10 or exists (
    select 1 from unnest(coalesce(p_tags, '{}'::text[])) as tags(value)
    where char_length(value) > 40
  ) then raise exception 'Review tags are invalid'; end if;
  select * into order_row from public.demo_orders where id = p_order_id;
  if not found then raise exception 'Demo order not found'; end if;
  if order_row.status <> 'completed' then raise exception 'Only completed orders can be reviewed'; end if;
  if exists(select 1 from public.demo_reviews where order_id = p_order_id) then
    raise exception 'This order already has a review';
  end if;
  insert into public.demo_reviews(order_id, store_id, student_label, rating, tags, comment)
    values(p_order_id, order_row.store_id, order_row.student_label, p_rating,
      coalesce(p_tags, '{}'::text[]), clean_comment)
    returning * into saved;
  return saved;
end;
$$;
revoke all on function public.demo_submit_review(bigint,integer,text[],text) from public;
grant execute on function public.demo_submit_review(bigint,integer,text[],text) to anon, authenticated;

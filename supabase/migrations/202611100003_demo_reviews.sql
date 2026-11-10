create table public.demo_reviews (
  id bigint generated always as identity primary key,
  order_id bigint not null unique references public.demo_orders(id) on delete cascade,
  store_id uuid not null references public.demo_stores(id),
  student_label text not null default 'Sample Student',
  rating integer not null check (rating between 1 and 5),
  tags text[] not null default '{}',
  comment text not null check (char_length(comment) between 1 and 1000),
  reply text not null default '' check (char_length(reply) <= 1000),
  created_at timestamptz not null default now()
);

alter table public.demo_reviews enable row level security;
create policy demo_reviews_public_read on public.demo_reviews
  for select to anon, authenticated using (true);
grant select on public.demo_reviews to anon, authenticated;

create or replace function public.demo_submit_review(
  p_order_id bigint,
  p_rating integer,
  p_tags text[] default '{}',
  p_comment text default ''
)
returns public.demo_reviews
language plpgsql security definer set search_path = '' as $$
declare
  order_row public.demo_orders%rowtype;
  saved public.demo_reviews%rowtype;
  clean_comment text := trim(coalesce(p_comment, ''));
begin
  if p_rating not between 1 and 5 then raise exception 'Choose a rating from 1 to 5'; end if;
  if char_length(clean_comment) not between 1 and 1000 then
    raise exception 'Please add a comment of up to 1000 characters';
  end if;
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
  values(p_order_id, order_row.store_id, order_row.student_label, p_rating, coalesce(p_tags, '{}'::text[]), clean_comment)
  returning * into saved;
  return saved;
end;
$$;

create or replace function public.demo_reply_to_review(
  p_review_id bigint,
  p_store_id uuid,
  p_reply text
)
returns public.demo_reviews
language plpgsql security definer set search_path = '' as $$
declare
  saved public.demo_reviews%rowtype;
  clean_reply text := trim(coalesce(p_reply, ''));
begin
  if char_length(clean_reply) not between 1 and 1000 then
    raise exception 'Enter a reply of up to 1000 characters';
  end if;
  update public.demo_reviews
     set reply = clean_reply
   where id = p_review_id and store_id = p_store_id
   returning * into saved;
  if not found then raise exception 'Demo review not found for this stall'; end if;
  return saved;
end;
$$;

revoke all on function public.demo_submit_review(bigint, integer, text[], text) from public;
revoke all on function public.demo_reply_to_review(bigint, uuid, text) from public;
grant execute on function public.demo_submit_review(bigint, integer, text[], text) to anon, authenticated;
grant execute on function public.demo_reply_to_review(bigint, uuid, text) to anon, authenticated;

do $$ begin
  alter publication supabase_realtime add table public.demo_reviews;
exception when duplicate_object then null;
end $$;

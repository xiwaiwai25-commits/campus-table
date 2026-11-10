create or replace function public.demo_reset()
returns void language plpgsql security definer set search_path = '' as $$
begin
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

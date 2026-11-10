-- Publish store availability changes so open clients can refresh hours and busy pauses.
do $$ begin
  alter publication supabase_realtime add table public.stores;
exception when duplicate_object then null;
end $$;
do $$ begin
  alter publication supabase_realtime add table public.demo_stores;
exception when duplicate_object then null;
end $$;

-- Trigger functions must not be callable through Supabase's public RPC surface.
revoke all on function public.create_mealsync_profile() from public, anon, authenticated;
revoke all on function public.archive_profile_data() from public, anon, authenticated;

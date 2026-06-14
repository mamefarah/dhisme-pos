-- Phase 2: Owner self-registration RPC
-- Adds one SECURITY DEFINER function so a brand-new authenticated user
-- (who has no profile row yet) can atomically create their store and owner
-- profile in a single call.
--
-- How to run:
--   Supabase CLI:       supabase db push
--   Supabase Dashboard: SQL Editor → paste this file → Run
--
-- No table changes. No RLS changes. No existing data touched.

create or replace function public.register_owner(
  p_full_name     text,
  p_store_name    text,
  p_phone         text    default null,
  p_store_phone   text    default null,
  p_store_address text    default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_store_id uuid;
begin
  -- Must be an authenticated Supabase user
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  -- One profile per auth user — prevent accidental double-registration
  if exists (select 1 from public.profiles where id = auth.uid()) then
    raise exception 'An account profile already exists for this login.';
  end if;

  -- Validate required fields
  if p_full_name is null or length(trim(p_full_name)) < 2 then
    raise exception 'Full name must be at least 2 characters';
  end if;
  if p_store_name is null or length(trim(p_store_name)) < 2 then
    raise exception 'Store name must be at least 2 characters';
  end if;

  -- Create store first, capture its UUID
  insert into public.stores(name, phone, address)
  values (
    trim(p_store_name),
    nullif(trim(coalesce(p_store_phone, '')), ''),
    nullif(trim(coalesce(p_store_address, '')), '')
  )
  returning id into v_store_id;

  -- Create owner profile linked to the new store
  insert into public.profiles(id, store_id, full_name, phone, role, is_active)
  values (
    auth.uid(),
    v_store_id,
    trim(p_full_name),
    nullif(trim(coalesce(p_phone, '')), ''),
    'owner',
    true
  );
end;
$$;

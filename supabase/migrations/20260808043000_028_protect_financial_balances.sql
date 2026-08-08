-- Production-readiness hardening: keep aggregate debt balances server-owned.
--
-- customers.total_balance and suppliers.total_balance are derived financial state.
-- Authenticated PostgREST clients must not be able to set them on INSERT or
-- change them on UPDATE. SECURITY DEFINER business RPCs continue to run with
-- their definer privileges and can maintain these fields transactionally.

-- Supplier creation historically omits store_id in the Flutter repository.
-- Resolve it server-side from the authenticated profile and prevent callers
-- from choosing a different store explicitly.
alter table public.suppliers
  alter column store_id set default public.current_user_store_id();

-- Remove broad mutation privileges first. RLS remains the tenant/role gate;
-- the column grants below further restrict what an authenticated client may
-- send through PostgREST.
revoke insert, update, delete on public.customers from public, anon, authenticated;
revoke insert, update, delete on public.suppliers from public, anon, authenticated;

-- Customer creation is intentionally limited to identity/contact fields.
-- Aggregate balance and credit-control fields use trusted defaults at creation.
grant insert (
  store_id,
  name,
  phone,
  location,
  notes
) on public.customers to authenticated;

-- Owner/manager RLS policies still determine who may update a customer.
-- total_balance is deliberately absent.
grant update (
  name,
  phone,
  location,
  notes,
  is_active,
  credit_limit,
  credit_days,
  credit_blocked
) on public.customers to authenticated;

-- Supplier store_id is filled by the server default above. total_balance is
-- deliberately absent from both INSERT and UPDATE grants.
grant insert (
  name,
  phone,
  address,
  contact_person,
  notes
) on public.suppliers to authenticated;

grant update (
  name,
  phone,
  address,
  contact_person,
  notes,
  is_active,
  updated_at
) on public.suppliers to authenticated;

-- Fail the migration if a future/default grant unexpectedly leaves the
-- aggregate balance columns directly writable by authenticated clients.
do $$
begin
  if has_column_privilege('authenticated', 'public.customers', 'total_balance', 'INSERT')
     or has_column_privilege('authenticated', 'public.customers', 'total_balance', 'UPDATE') then
    raise exception 'customers.total_balance remains directly writable by authenticated';
  end if;

  if has_column_privilege('authenticated', 'public.suppliers', 'total_balance', 'INSERT')
     or has_column_privilege('authenticated', 'public.suppliers', 'total_balance', 'UPDATE') then
    raise exception 'suppliers.total_balance remains directly writable by authenticated';
  end if;
end;
$$;

-- Follow-up to migration 028.
--
-- A clean reconstruction of the full migration chain showed that authenticated
-- users cannot rely on an earlier explicit SELECT grant for customers and
-- suppliers. Column-level UPDATE permissions still need SELECT access for
-- normal reads and for UPDATE predicates (for example, WHERE id = ...).
--
-- Keep aggregate balances server-owned while explicitly restoring the read
-- privilege required by the application. RLS remains the tenant/role filter.

grant select on public.customers to authenticated;
grant select on public.suppliers to authenticated;

-- Fail fast if future grant changes remove the read access required by the app.
do $$
begin
  if not has_table_privilege('authenticated', 'public.customers', 'SELECT') then
    raise exception 'authenticated must retain SELECT on public.customers';
  end if;

  if not has_table_privilege('authenticated', 'public.suppliers', 'SELECT') then
    raise exception 'authenticated must retain SELECT on public.suppliers';
  end if;

  -- Preserve migration 028's core invariant while repairing read access.
  if has_column_privilege('authenticated', 'public.customers', 'total_balance', 'INSERT')
     or has_column_privilege('authenticated', 'public.customers', 'total_balance', 'UPDATE') then
    raise exception 'customers.total_balance must remain server-owned';
  end if;

  if has_column_privilege('authenticated', 'public.suppliers', 'total_balance', 'INSERT')
     or has_column_privilege('authenticated', 'public.suppliers', 'total_balance', 'UPDATE') then
    raise exception 'suppliers.total_balance must remain server-owned';
  end if;
end;
$$;

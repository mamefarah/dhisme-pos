-- products.current_stock must only change via the create_cash_sale /
-- adjust_stock / record_return RPCs, which write a matching stock_movements
-- row for the audit trail. The "owner manager products update" RLS policy
-- (20260614180000_phase4_role_based_access.sql) never restricted which
-- columns that update could touch, so any owner/manager client can currently
-- run `update products set current_stock = ...` straight through PostgREST,
-- silently bypassing both the RPCs and the audit trail.
--
-- This follows the same column-grant pattern already used for
-- customers.total_balance / suppliers.total_balance
-- (20260808043000_028_protect_financial_balances.sql): RLS still decides who
-- may update a product at all; these grants further restrict which columns
-- an authenticated client may send. current_stock is deliberately absent.
--
-- current_stock remains part of the INSERT grant: setting the starting stock
-- for a brand-new product is a one-time setup value, not a stock movement —
-- there is no "previous stock" to log, so it doesn't need to go through
-- adjust_stock.
--
-- How to run:
--   Supabase CLI:       supabase db push
--   Supabase Dashboard: SQL Editor -> paste this file -> Run

revoke insert, update, delete on public.products from public, anon, authenticated;

grant insert (
  store_id,
  category_id,
  name,
  unit,
  buying_price,
  selling_price,
  minimum_selling_price,
  current_stock,
  minimum_stock,
  is_active,
  notes
) on public.products to authenticated;

-- current_stock is deliberately absent: post-creation stock changes must go
-- through adjust_stock/create_cash_sale/record_return.
grant update (
  category_id,
  name,
  unit,
  buying_price,
  selling_price,
  minimum_selling_price,
  minimum_stock,
  is_active,
  notes,
  updated_at
) on public.products to authenticated;

-- Fail the migration if a future/default grant unexpectedly leaves
-- current_stock directly writable by authenticated clients on UPDATE.
do $$
begin
  if has_column_privilege('authenticated', 'public.products', 'current_stock', 'UPDATE') then
    raise exception 'products.current_stock remains directly writable by authenticated on UPDATE';
  end if;
end;
$$;

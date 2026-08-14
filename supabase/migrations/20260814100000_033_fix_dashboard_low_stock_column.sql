-- Fix dashboard_stats_v2: low-stock count referenced a column that doesn't exist.
--
-- Migration 025 (legacy_compatibility) introduced p.reorder_level, but the
-- products table (001_init.sql) only ever defined minimum_stock — reorder_level
-- was never created. Every call to dashboard_stats()/dashboard_stats_v2() has
-- been raising "column p.reorder_level does not exist" since migration 025 was
-- applied, breaking the owner/manager/seller dashboard entirely.
--
-- This re-creates the function identically except for that one column
-- reference, restoring it to the low-stock definition used everywhere else in
-- the schema (see 001_init.sql:667, product.dart's isLowStock getter).
--
-- How to run:
--   Supabase CLI:       supabase db push
--   Supabase Dashboard: SQL Editor -> paste this file -> Run

create or replace function public.dashboard_stats_v2()
returns jsonb
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_store_id uuid := public.current_user_store_id();
  v_role text := public.current_user_role();
  v_user_id uuid := auth.uid();
  v_today date := current_date;
  v_sales numeric(14,2) := 0;
  v_cash numeric(14,2) := 0;
  v_bank numeric(14,2) := 0;
  v_mobile numeric(14,2) := 0;
  v_credit numeric(14,2) := 0;
  v_pending integer := 0;
  v_low_stock integer := 0;
  v_customer_debt numeric(14,2) := 0;
begin
  if v_store_id is null then raise exception 'User profile/store not found'; end if;
  if v_role not in ('owner','manager','seller') then raise exception 'Not allowed'; end if;

  select coalesce(sum(s.total_amount-s.refunded_amount),0)
  into v_sales
  from public.sales s
  where s.store_id=v_store_id and s.status='completed' and s.created_at::date=v_today
    and (v_role in ('owner','manager') or s.seller_id=v_user_id);

  select coalesce(sum(case when cl.direction='inflow' then cl.amount else -cl.amount end),0)
  into v_cash
  from public.cash_ledger cl
  where cl.store_id=v_store_id and cl.payment_method='cash' and cl.occurred_at::date=v_today
    and (v_role in ('owner','manager') or cl.user_id=v_user_id);

  select coalesce(sum(case when cl.direction='inflow' then cl.amount else -cl.amount end),0)
  into v_bank
  from public.cash_ledger cl
  where cl.store_id=v_store_id and cl.payment_method='bank' and cl.occurred_at::date=v_today
    and (v_role in ('owner','manager') or cl.user_id=v_user_id);

  select coalesce(sum(case when cl.direction='inflow' then cl.amount else -cl.amount end),0)
  into v_mobile
  from public.cash_ledger cl
  where cl.store_id=v_store_id and cl.payment_method='mobile_money' and cl.occurred_at::date=v_today
    and (v_role in ('owner','manager') or cl.user_id=v_user_id);

  select coalesce(sum(s.total_amount-s.refunded_amount),0)
  into v_credit
  from public.sales s
  where s.store_id=v_store_id and s.status='completed' and s.sale_type='credit'
    and s.created_at::date=v_today
    and (v_role in ('owner','manager') or s.seller_id=v_user_id);

  select count(*) into v_pending
  from public.approval_requests a
  where a.store_id=v_store_id and a.status='pending'
    and (v_role in ('owner','manager') or a.requested_by=v_user_id);

  select count(*) into v_low_stock
  from public.products p
  where p.store_id=v_store_id and p.is_active=true and p.current_stock<=p.minimum_stock;

  if v_role in ('owner','manager') then
    select coalesce(sum(c.total_balance),0) into v_customer_debt
    from public.customers c where c.store_id=v_store_id and c.is_active=true;
  end if;

  return jsonb_build_object(
    'today_sales',v_sales,'today_cash',v_cash,'today_bank',v_bank,
    'today_mobile_money',v_mobile,'today_credit',v_credit,
    'pending_approvals',v_pending,'low_stock_items',v_low_stock,
    'customer_debt',v_customer_debt,
    'scope',case when v_role='seller' then 'own' else 'store' end
  );
end;
$$;

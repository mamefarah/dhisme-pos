-- Supabase performance advisor: auth_rls_initplan warnings on payments,
-- stock_movements, approval_requests, daily_cash_closings, customer_payments.
-- Each policy re-evaluates current_user_store_id()/current_user_role()/
-- auth.uid() once per row instead of once per statement. Wrapping each call
-- in `(select ...)` (the same pattern already used by migrations 020/021/027
-- and 037) lets Postgres evaluate it once via an InitPlan. This changes
-- nothing about who can see what — only how many times the same scalar
-- lookup runs — so it is purely a performance fix, not an authorization
-- change.
--
-- How to run:
--   Supabase CLI:       supabase db push
--   Supabase Dashboard: SQL Editor -> paste this file -> Run

drop policy if exists "payments read" on public.payments;
create policy "payments read"
on public.payments
for select
to authenticated
using (
  store_id = (select public.current_user_store_id())
  and (
    (select public.current_user_role()) in ('owner', 'manager')
    or seller_id = (select auth.uid())
  )
);

drop policy if exists "stock movements read" on public.stock_movements;
create policy "stock movements read"
on public.stock_movements
for select
to authenticated
using (
  store_id = (select public.current_user_store_id())
  and (
    (select public.current_user_role()) in ('owner', 'manager')
    or created_by = (select auth.uid())
  )
);

drop policy if exists "approvals read" on public.approval_requests;
create policy "approvals read"
on public.approval_requests
for select
to authenticated
using (
  store_id = (select public.current_user_store_id())
  and (
    (select public.current_user_role()) in ('owner', 'manager')
    or requested_by = (select auth.uid())
  )
);

drop policy if exists "closings read" on public.daily_cash_closings;
create policy "closings read"
on public.daily_cash_closings
for select
to authenticated
using (
  store_id = (select public.current_user_store_id())
  and (
    (select public.current_user_role()) in ('owner', 'manager')
    or seller_id = (select auth.uid())
  )
);

drop policy if exists "customer_payments select store" on public.customer_payments;
create policy "customer_payments select store"
on public.customer_payments
for select
to authenticated
using (
  store_id = (select public.current_user_store_id())
  and (
    (select public.current_user_role()) in ('owner', 'manager')
    or received_by = (select auth.uid())
  )
);

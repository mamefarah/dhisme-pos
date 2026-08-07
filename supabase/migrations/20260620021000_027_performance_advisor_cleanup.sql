-- Supabase advisor cleanup.
-- Remove broad duplicate read policies, cache auth/helper calls per statement,
-- and add indexes for newly introduced foreign keys.

create index if not exists idx_customer_payment_allocations_store
  on public.customer_payment_allocations(store_id);
create index if not exists idx_operation_idempotency_created_by
  on public.operation_idempotency(created_by);
create index if not exists idx_supplier_payment_allocations_store
  on public.supplier_payment_allocations(store_id);

drop policy if exists "expenses read same store" on public.expenses;
drop policy if exists "supplier payments read same store" on public.supplier_payments;
drop policy if exists "returns read same store" on public.returns;
drop policy if exists "return items read same store" on public.return_items;

drop policy if exists "notifications update own" on public.notifications;
create policy "notifications update own"
on public.notifications
for update
to authenticated
using (
  store_id = (select public.current_user_store_id())
  and (user_id = (select auth.uid()) or user_id is null)
)
with check (
  store_id = (select public.current_user_store_id())
  and (user_id = (select auth.uid()) or user_id is null)
);

drop policy if exists "sales read" on public.sales;
create policy "sales read"
on public.sales
for select
to authenticated
using (
  store_id = (select public.current_user_store_id())
  and (
    (select public.current_user_role()) in ('owner','manager')
    or seller_id = (select auth.uid())
  )
);

drop policy if exists "sale items read" on public.sale_items;
create policy "sale items read"
on public.sale_items
for select
to authenticated
using (
  store_id = (select public.current_user_store_id())
  and (
    (select public.current_user_role()) in ('owner','manager')
    or exists (
      select 1
      from public.sales s
      where s.id = sale_items.sale_id
        and s.seller_id = (select auth.uid())
    )
  )
);

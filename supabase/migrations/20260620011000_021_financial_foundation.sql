-- Audit remediation phase 2: immutable money ledger, invoice allocations and idempotency.

create table if not exists public.operation_idempotency (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  operation_type text not null,
  idempotency_key text not null,
  result_id uuid,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  unique(store_id, operation_type, idempotency_key)
);

create table if not exists public.cash_ledger (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  user_id uuid references public.profiles(id),
  direction text not null check (direction in ('inflow','outflow')),
  payment_method text not null check (payment_method in ('cash','bank','mobile_money')),
  amount numeric(14,2) not null check (amount > 0),
  source_type text not null,
  source_id uuid not null,
  description text,
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique(store_id, source_type, source_id, payment_method, direction)
);

create table if not exists public.customer_payment_allocations (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  payment_id uuid not null references public.customer_payments(id) on delete cascade,
  sale_id uuid not null references public.sales(id),
  amount numeric(14,2) not null check (amount > 0),
  created_at timestamptz not null default now(),
  unique(payment_id, sale_id)
);

create table if not exists public.supplier_payment_allocations (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  payment_id uuid not null references public.supplier_payments(id) on delete cascade,
  purchase_id uuid not null references public.purchases(id),
  amount numeric(14,2) not null check (amount > 0),
  created_at timestamptz not null default now(),
  unique(payment_id, purchase_id)
);

create table if not exists public.cash_adjustments (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  adjustment_type text not null check (
    adjustment_type in ('opening_float','cash_deposit','owner_withdrawal','other_inflow','other_outflow')
  ),
  direction text not null check (direction in ('inflow','outflow')),
  amount numeric(14,2) not null check (amount > 0),
  adjustment_date date not null default current_date,
  reference_no text,
  notes text,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

create index if not exists idx_idempotency_store_type on public.operation_idempotency(store_id, operation_type, created_at desc);
create index if not exists idx_cash_ledger_store_date on public.cash_ledger(store_id, occurred_at desc);
create index if not exists idx_cash_ledger_user_date on public.cash_ledger(user_id, occurred_at desc);
create index if not exists idx_cash_ledger_source on public.cash_ledger(source_type, source_id);
create index if not exists idx_customer_alloc_payment on public.customer_payment_allocations(payment_id);
create index if not exists idx_customer_alloc_sale on public.customer_payment_allocations(sale_id);
create index if not exists idx_supplier_alloc_payment on public.supplier_payment_allocations(payment_id);
create index if not exists idx_supplier_alloc_purchase on public.supplier_payment_allocations(purchase_id);
create index if not exists idx_cash_adjustments_store_date on public.cash_adjustments(store_id, adjustment_date desc);
create index if not exists idx_cash_adjustments_created_by on public.cash_adjustments(created_by);

alter table public.operation_idempotency enable row level security;
alter table public.cash_ledger enable row level security;
alter table public.customer_payment_allocations enable row level security;
alter table public.supplier_payment_allocations enable row level security;
alter table public.cash_adjustments enable row level security;

-- Idempotency rows are internal-only: no direct client policies.

drop policy if exists "cash ledger managers or own" on public.cash_ledger;
create policy "cash ledger managers or own" on public.cash_ledger
for select to authenticated
using (
  store_id = (select public.current_user_store_id())
  and (
    (select public.current_user_role()) in ('owner','manager')
    or user_id = (select auth.uid())
  )
);

drop policy if exists "customer allocations same store" on public.customer_payment_allocations;
create policy "customer allocations same store" on public.customer_payment_allocations
for select to authenticated
using (
  store_id = (select public.current_user_store_id())
  and (select public.current_user_role()) in ('owner','manager')
);

drop policy if exists "supplier allocations managers" on public.supplier_payment_allocations;
create policy "supplier allocations managers" on public.supplier_payment_allocations
for select to authenticated
using (
  store_id = (select public.current_user_store_id())
  and (select public.current_user_role()) in ('owner','manager')
);

drop policy if exists "cash adjustments managers" on public.cash_adjustments;
create policy "cash adjustments managers" on public.cash_adjustments
for select to authenticated
using (
  store_id = (select public.current_user_store_id())
  and (select public.current_user_role()) in ('owner','manager')
);

revoke all on public.operation_idempotency from public, anon, authenticated;
revoke insert, update, delete on public.cash_ledger from public, anon, authenticated;
revoke insert, update, delete on public.customer_payment_allocations from public, anon, authenticated;
revoke insert, update, delete on public.supplier_payment_allocations from public, anon, authenticated;
revoke insert, update, delete on public.cash_adjustments from public, anon, authenticated;

-- Internal helpers are placed in a non-exposed schema.
create or replace function private.claim_operation(
  p_store_id uuid,
  p_operation_type text,
  p_idempotency_key text,
  p_user_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_guard_id uuid;
  v_result_id uuid;
begin
  if p_idempotency_key is null or length(trim(p_idempotency_key)) < 8 then
    raise exception 'A valid idempotency key is required';
  end if;

  insert into public.operation_idempotency(store_id, operation_type, idempotency_key, created_by)
  values (p_store_id, p_operation_type, trim(p_idempotency_key), p_user_id)
  on conflict (store_id, operation_type, idempotency_key) do nothing
  returning id into v_guard_id;

  if v_guard_id is not null then
    return jsonb_build_object('claimed', true, 'guard_id', v_guard_id);
  end if;

  select result_id into v_result_id
  from public.operation_idempotency
  where store_id = p_store_id
    and operation_type = p_operation_type
    and idempotency_key = trim(p_idempotency_key);

  if v_result_id is null then
    raise exception 'This operation is already being processed. Wait and refresh.';
  end if;

  return jsonb_build_object('claimed', false, 'result_id', v_result_id);
end;
$$;

create or replace function private.complete_operation(p_guard_id uuid, p_result_id uuid)
returns void
language sql
security definer
set search_path = public, private
as $$
  update public.operation_idempotency
  set result_id = p_result_id
  where id = p_guard_id and result_id is null
$$;

revoke all on function private.claim_operation(uuid,text,text,uuid) from public, anon, authenticated;
revoke all on function private.complete_operation(uuid,uuid) from public, anon, authenticated;

-- Backfill a complete ledger from existing money movements.
insert into public.cash_ledger(store_id, user_id, direction, payment_method, amount, source_type, source_id, description, occurred_at)
select store_id, seller_id, 'inflow', payment_method, amount, 'sale_payment', id,
       'Sale payment backfill', created_at
from public.payments
where payment_method in ('cash','bank','mobile_money') and amount > 0
on conflict do nothing;

insert into public.cash_ledger(store_id, user_id, direction, payment_method, amount, source_type, source_id, description, occurred_at)
select store_id, received_by, 'inflow', payment_method, amount, 'customer_payment', id,
       'Customer payment backfill', created_at
from public.customer_payments
where payment_method in ('cash','bank','mobile_money') and amount > 0
on conflict do nothing;

insert into public.cash_ledger(store_id, user_id, direction, payment_method, amount, source_type, source_id, description, occurred_at)
select store_id, created_by, 'outflow', payment_method, amount, 'expense', id,
       'Expense backfill', created_at
from public.expenses
where payment_method in ('cash','bank','mobile_money') and amount > 0
on conflict do nothing;

insert into public.cash_ledger(store_id, user_id, direction, payment_method, amount, source_type, source_id, description, occurred_at)
select store_id, paid_by, 'outflow', payment_method, amount, 'supplier_payment', id,
       'Supplier payment backfill', created_at
from public.supplier_payments
where payment_method in ('cash','bank','mobile_money') and amount > 0
on conflict do nothing;

insert into public.cash_ledger(store_id, user_id, direction, payment_method, amount, source_type, source_id, description, occurred_at)
select store_id, created_by, 'outflow', refund_method, refund_amount, 'return_refund', id,
       'Return refund backfill', created_at
from public.returns
where refund_method in ('cash','bank','mobile_money') and refund_amount > 0
on conflict do nothing;

-- Reconstruct historical customer allocations FIFO. Existing data is small and this is repeatable.
do $$
declare
  p record;
  s record;
  v_remaining numeric(14,2);
  v_allocate numeric(14,2);
begin
  for p in
    select cp.*,
           cp.amount - coalesce((select sum(a.amount) from public.customer_payment_allocations a where a.payment_id = cp.id),0) as unallocated
    from public.customer_payments cp
    order by cp.customer_id, cp.created_at, cp.id
  loop
    v_remaining := p.unallocated;
    if v_remaining <= 0 then continue; end if;

    for s in
      select id, balance_amount
      from public.sales
      where store_id = p.store_id
        and customer_id = p.customer_id
        and sale_type = 'credit'
        and status = 'completed'
        and balance_amount > 0
        and created_at <= p.created_at
      order by created_at, id
      for update
    loop
      exit when v_remaining <= 0;
      v_allocate := least(v_remaining, s.balance_amount);

      insert into public.customer_payment_allocations(store_id, payment_id, sale_id, amount)
      values (p.store_id, p.id, s.id, v_allocate)
      on conflict (payment_id, sale_id) do update
      set amount = excluded.amount;

      update public.sales
      set paid_amount = least(total_amount - refunded_amount, paid_amount + v_allocate),
          balance_amount = greatest(0, balance_amount - v_allocate),
          payment_status = case
            when greatest(0, balance_amount - v_allocate) = 0 then 'paid'
            else 'partial'
          end
      where id = s.id;

      v_remaining := v_remaining - v_allocate;
    end loop;
  end loop;

  update public.customers c
  set total_balance = coalesce((
    select sum(s.balance_amount)
    from public.sales s
    where s.customer_id = c.id
      and s.store_id = c.store_id
      and s.sale_type = 'credit'
      and s.status = 'completed'
  ),0);
end $$;

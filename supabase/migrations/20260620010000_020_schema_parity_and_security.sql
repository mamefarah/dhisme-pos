-- Audit remediation phase 1: make repository migrations reproduce the live Phase 2 schema
-- and remove unintended PUBLIC/anon execution from privileged RPCs.

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

alter table public.suppliers add column if not exists total_balance numeric(14,2) not null default 0;
alter table public.purchases add column if not exists paid_amount numeric(14,2) not null default 0;
alter table public.purchases add column if not exists balance_amount numeric(14,2) not null default 0;
alter table public.purchases add column if not exists payment_method text;
alter table public.sales add column if not exists refunded_amount numeric(14,2) not null default 0;
alter table public.sale_items add column if not exists returned_quantity numeric(14,2) not null default 0;

create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  category text not null,
  amount numeric(14,2) not null check (amount > 0),
  expense_date date not null default current_date,
  payment_method text not null default 'cash' check (payment_method in ('cash','bank','mobile_money')),
  reference_no text,
  notes text,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

create table if not exists public.supplier_payments (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  supplier_id uuid not null references public.suppliers(id),
  amount numeric(14,2) not null check (amount > 0),
  payment_method text not null default 'cash' check (payment_method in ('cash','bank','mobile_money')),
  reference_no text,
  notes text,
  paid_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

create table if not exists public.returns (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  sale_id uuid not null references public.sales(id),
  customer_id uuid references public.customers(id),
  seller_id uuid references public.profiles(id),
  return_no text not null,
  subtotal numeric(14,2) not null default 0,
  refund_amount numeric(14,2) not null default 0,
  refund_method text not null default 'cash' check (refund_method in ('cash','bank','mobile_money','credit_adjustment')),
  reason text not null,
  status text not null default 'completed' check (status in ('completed','cancelled')),
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  unique(store_id, return_no)
);

create table if not exists public.return_items (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  return_id uuid not null references public.returns(id) on delete cascade,
  sale_item_id uuid not null references public.sale_items(id),
  product_id uuid not null references public.products(id),
  product_name text not null,
  unit text not null,
  quantity numeric(14,2) not null check (quantity > 0),
  unit_price numeric(14,2) not null check (unit_price >= 0),
  total_price numeric(14,2) not null check (total_price >= 0)
);

create index if not exists idx_expenses_store_date on public.expenses(store_id, expense_date desc);
create index if not exists idx_expenses_created_by on public.expenses(created_by);
create index if not exists idx_supplier_payments_store on public.supplier_payments(store_id, created_at desc);
create index if not exists idx_supplier_payments_supplier on public.supplier_payments(supplier_id, created_at desc);
create index if not exists idx_supplier_payments_paid_by on public.supplier_payments(paid_by);
create index if not exists idx_returns_store_date on public.returns(store_id, created_at desc);
create index if not exists idx_returns_sale on public.returns(sale_id);
create index if not exists idx_returns_customer on public.returns(customer_id);
create index if not exists idx_returns_seller on public.returns(seller_id);
create index if not exists idx_returns_created_by on public.returns(created_by);
create index if not exists idx_return_items_return on public.return_items(return_id);
create index if not exists idx_return_items_sale_item on public.return_items(sale_item_id);
create index if not exists idx_return_items_product on public.return_items(product_id);
create index if not exists idx_return_items_store on public.return_items(store_id);

alter table public.expenses enable row level security;
alter table public.supplier_payments enable row level security;
alter table public.returns enable row level security;
alter table public.return_items enable row level security;

-- Read access follows explicit role rules. All writes go through audited RPCs.
drop policy if exists "expenses read managers" on public.expenses;
create policy "expenses read managers" on public.expenses
for select to authenticated
using (
  store_id = (select public.current_user_store_id())
  and (select public.current_user_role()) in ('owner','manager')
);

drop policy if exists "supplier payments read managers" on public.supplier_payments;
create policy "supplier payments read managers" on public.supplier_payments
for select to authenticated
using (
  store_id = (select public.current_user_store_id())
  and (select public.current_user_role()) in ('owner','manager')
);

drop policy if exists "returns read managers or seller own" on public.returns;
create policy "returns read managers or seller own" on public.returns
for select to authenticated
using (
  store_id = (select public.current_user_store_id())
  and (
    (select public.current_user_role()) in ('owner','manager')
    or seller_id = (select auth.uid())
  )
);

drop policy if exists "return items read allowed return" on public.return_items;
create policy "return items read allowed return" on public.return_items
for select to authenticated
using (
  store_id = (select public.current_user_store_id())
  and exists (
    select 1 from public.returns r
    where r.id = return_id
      and r.store_id = (select public.current_user_store_id())
      and (
        (select public.current_user_role()) in ('owner','manager')
        or r.seller_id = (select auth.uid())
      )
  )
);

-- Remove PostgreSQL's default PUBLIC EXECUTE privilege from every app RPC.
-- Explicit grants below are the only API surface.
do $$
declare
  r record;
begin
  for r in
    select p.oid::regprocedure as signature
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in (
        'adjust_stock','create_cash_sale','create_store_invite','current_user_name',
        'current_user_role','current_user_store_id','customer_statement','dashboard_stats',
        'decide_approval_request','log_action','new_invoice_no','new_return_no',
        'record_customer_payment','record_expense','record_purchase','record_return',
        'record_supplier_payment','register_owner','register_with_invite',
        'request_credit_sale','review_daily_cash_closing','submit_daily_cash_closing'
      )
  loop
    execute format('revoke all on function %s from public, anon, authenticated', r.signature);
  end loop;
end $$;

-- RLS helper functions must remain callable by signed-in users.
grant execute on function public.current_user_store_id() to authenticated;
grant execute on function public.current_user_role() to authenticated;
grant execute on function public.current_user_name() to authenticated;

-- Business API used by the current application. Internal helpers are intentionally omitted.
do $$
declare
  r record;
begin
  for r in
    select p.oid::regprocedure as signature
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in (
        'adjust_stock','create_cash_sale','create_store_invite','customer_statement',
        'dashboard_stats','decide_approval_request','record_customer_payment',
        'record_expense','record_purchase','record_return','record_supplier_payment',
        'register_owner','register_with_invite','request_credit_sale',
        'review_daily_cash_closing','submit_daily_cash_closing'
      )
  loop
    execute format('grant execute on function %s to authenticated', r.signature);
  end loop;
end $$;

-- Direct table writes are denied; RPCs own all financial mutations.
revoke insert, update, delete on public.expenses from authenticated, anon;
revoke insert, update, delete on public.supplier_payments from authenticated, anon;
revoke insert, update, delete on public.returns from authenticated, anon;
revoke insert, update, delete on public.return_items from authenticated, anon;

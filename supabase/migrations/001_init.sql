-- Dhisme POS Supabase backend
-- Run this in Supabase SQL Editor.

create extension if not exists "pgcrypto";

-- =========================
-- Tables
-- =========================

create table if not exists public.stores (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text,
  address text,
  currency text not null default 'ETB',
  created_at timestamptz not null default now()
);

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  store_id uuid not null references public.stores(id) on delete cascade,
  full_name text not null,
  phone text,
  role text not null check (role in ('owner', 'seller')),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now(),
  unique(store_id, name)
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  category_id uuid references public.categories(id) on delete set null,
  name text not null,
  unit text not null,
  buying_price numeric(12,2) not null default 0,
  selling_price numeric(12,2) not null,
  minimum_selling_price numeric(12,2) not null default 0,
  current_stock numeric(12,2) not null default 0,
  minimum_stock numeric(12,2) not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (selling_price >= 0),
  check (current_stock >= 0)
);

create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  name text not null,
  phone text,
  location text,
  total_balance numeric(12,2) not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.sales (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  seller_id uuid not null references public.profiles(id),
  customer_id uuid references public.customers(id),
  invoice_no text not null,
  sale_type text not null check (sale_type in ('cash', 'credit', 'partial')),
  subtotal numeric(12,2) not null default 0,
  discount numeric(12,2) not null default 0,
  total_amount numeric(12,2) not null default 0,
  paid_amount numeric(12,2) not null default 0,
  balance_amount numeric(12,2) not null default 0,
  payment_status text not null check (payment_status in ('paid', 'partial', 'unpaid')),
  approval_status text not null default 'not_required' check (approval_status in ('not_required', 'pending', 'approved', 'rejected')),
  status text not null default 'completed' check (status in ('draft', 'completed', 'cancelled')),
  notes text,
  created_at timestamptz not null default now(),
  unique(store_id, invoice_no)
);

create table if not exists public.sale_items (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  sale_id uuid not null references public.sales(id) on delete cascade,
  product_id uuid not null references public.products(id),
  product_name text not null,
  unit text not null,
  quantity numeric(12,2) not null check (quantity > 0),
  unit_price numeric(12,2) not null check (unit_price >= 0),
  total_price numeric(12,2) not null check (total_price >= 0)
);

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  sale_id uuid references public.sales(id) on delete cascade,
  customer_id uuid references public.customers(id),
  seller_id uuid references public.profiles(id),
  amount numeric(12,2) not null check (amount >= 0),
  payment_method text not null check (payment_method in ('cash', 'bank', 'mobile_money', 'mixed')),
  reference_no text,
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists public.stock_movements (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  product_id uuid not null references public.products(id),
  movement_type text not null check (movement_type in ('sale', 'purchase', 'adjustment_in', 'adjustment_out', 'return')),
  quantity numeric(12,2) not null check (quantity > 0),
  previous_stock numeric(12,2) not null,
  new_stock numeric(12,2) not null,
  reference_id uuid,
  created_by uuid references public.profiles(id),
  approval_status text not null default 'not_required' check (approval_status in ('not_required', 'pending', 'approved', 'rejected')),
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists public.approval_requests (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  requested_by uuid not null references public.profiles(id),
  approved_by uuid references public.profiles(id),
  request_type text not null check (request_type in ('credit_sale', 'large_discount', 'sale_cancel', 'stock_adjustment', 'refund', 'price_change')),
  reference_id uuid,
  amount numeric(12,2),
  reason text not null,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  owner_comment text,
  created_at timestamptz not null default now(),
  decided_at timestamptz
);

create table if not exists public.daily_cash_closings (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  seller_id uuid not null references public.profiles(id),
  closing_date date not null,
  expected_cash numeric(12,2) not null default 0,
  actual_cash numeric(12,2) not null default 0,
  cash_difference numeric(12,2) not null default 0,
  bank_total numeric(12,2) not null default 0,
  mobile_money_total numeric(12,2) not null default 0,
  credit_sales_total numeric(12,2) not null default 0,
  notes text,
  status text not null default 'submitted' check (status in ('submitted', 'approved', 'rejected')),
  created_at timestamptz not null default now(),
  reviewed_by uuid references public.profiles(id),
  reviewed_at timestamptz,
  unique(store_id, seller_id, closing_date)
);

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  store_id uuid references public.stores(id) on delete cascade,
  user_id uuid references public.profiles(id),
  action text not null,
  table_name text,
  record_id uuid,
  old_data jsonb,
  new_data jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  user_id uuid references public.profiles(id),
  title text not null,
  message text not null,
  type text,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists idx_profiles_store on public.profiles(store_id);
create index if not exists idx_products_store on public.products(store_id);
create index if not exists idx_sales_store_date on public.sales(store_id, created_at desc);
create index if not exists idx_sales_seller_date on public.sales(seller_id, created_at desc);
create index if not exists idx_approval_store_status on public.approval_requests(store_id, status, created_at desc);
create index if not exists idx_payments_store_date on public.payments(store_id, created_at desc);

-- =========================
-- Helper functions
-- =========================

create or replace function public.current_user_store_id()
returns uuid
language sql
security definer
set search_path = public
as $$
  select store_id from public.profiles where id = auth.uid() and is_active = true
$$;

create or replace function public.current_user_role()
returns text
language sql
security definer
set search_path = public
as $$
  select role from public.profiles where id = auth.uid() and is_active = true
$$;

create or replace function public.current_user_name()
returns text
language sql
security definer
set search_path = public
as $$
  select full_name from public.profiles where id = auth.uid() and is_active = true
$$;

create or replace function public.new_invoice_no()
returns text
language sql
as $$
  select 'INV-' || to_char(now(), 'YYYYMMDD-HH24MISS') || '-' || upper(substring(gen_random_uuid()::text, 1, 6))
$$;

create or replace function public.log_action(p_action text, p_table_name text, p_record_id uuid, p_old jsonb default null, p_new jsonb default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.audit_logs(store_id, user_id, action, table_name, record_id, old_data, new_data)
  values (public.current_user_store_id(), auth.uid(), p_action, p_table_name, p_record_id, p_old, p_new);
end;
$$;

-- =========================
-- RLS
-- =========================

alter table public.stores enable row level security;
alter table public.profiles enable row level security;
alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.customers enable row level security;
alter table public.sales enable row level security;
alter table public.sale_items enable row level security;
alter table public.payments enable row level security;
alter table public.stock_movements enable row level security;
alter table public.approval_requests enable row level security;
alter table public.daily_cash_closings enable row level security;
alter table public.audit_logs enable row level security;
alter table public.notifications enable row level security;

-- Drop policies safely for repeatable migration use in dev
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT schemaname, tablename, policyname FROM pg_policies WHERE schemaname = 'public'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', r.policyname, r.schemaname, r.tablename);
  END LOOP;
END $$;

create policy "read own store" on public.stores for select to authenticated using (id = public.current_user_store_id());
create policy "profiles read own store" on public.profiles for select to authenticated using (store_id = public.current_user_store_id());
create policy "owner updates profiles" on public.profiles for update to authenticated using (store_id = public.current_user_store_id() and public.current_user_role() = 'owner');

create policy "categories read" on public.categories for select to authenticated using (store_id = public.current_user_store_id());
create policy "owner categories insert" on public.categories for insert to authenticated with check (store_id = public.current_user_store_id() and public.current_user_role() = 'owner');
create policy "owner categories update" on public.categories for update to authenticated using (store_id = public.current_user_store_id() and public.current_user_role() = 'owner');

create policy "products read" on public.products for select to authenticated using (store_id = public.current_user_store_id());
create policy "owner products insert" on public.products for insert to authenticated with check (store_id = public.current_user_store_id() and public.current_user_role() = 'owner');
create policy "owner products update" on public.products for update to authenticated using (store_id = public.current_user_store_id() and public.current_user_role() = 'owner');

create policy "customers read" on public.customers for select to authenticated using (store_id = public.current_user_store_id());
create policy "customers insert" on public.customers for insert to authenticated with check (store_id = public.current_user_store_id());
create policy "customers update owner" on public.customers for update to authenticated using (store_id = public.current_user_store_id() and public.current_user_role() = 'owner');

create policy "sales read" on public.sales for select to authenticated using (store_id = public.current_user_store_id());
create policy "sale items read" on public.sale_items for select to authenticated using (store_id = public.current_user_store_id());
create policy "payments read" on public.payments for select to authenticated using (store_id = public.current_user_store_id());
create policy "stock movements read" on public.stock_movements for select to authenticated using (store_id = public.current_user_store_id());
create policy "approvals read" on public.approval_requests for select to authenticated using (store_id = public.current_user_store_id());
create policy "closings read" on public.daily_cash_closings for select to authenticated using (store_id = public.current_user_store_id());
create policy "audit read" on public.audit_logs for select to authenticated using (store_id = public.current_user_store_id());
create policy "notifications read" on public.notifications for select to authenticated using (store_id = public.current_user_store_id());
create policy "notifications update own" on public.notifications for update to authenticated using (store_id = public.current_user_store_id() and (user_id = auth.uid() or user_id is null));

-- Direct writes to sales, payments, stock movements and approvals are intentionally restricted.
-- Use secure RPC functions below.

-- =========================
-- RPC: create cash/bank/mobile sale
-- =========================

create or replace function public.create_cash_sale(
  p_customer_id uuid,
  p_items jsonb,
  p_payment_method text,
  p_reference_no text default null,
  p_discount numeric default 0,
  p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_store_id uuid := public.current_user_store_id();
  v_role text := public.current_user_role();
  v_sale_id uuid := gen_random_uuid();
  v_invoice text := public.new_invoice_no();
  v_subtotal numeric(12,2) := 0;
  v_total numeric(12,2) := 0;
  v_item jsonb;
  v_product public.products%rowtype;
  v_qty numeric(12,2);
  v_line_total numeric(12,2);
begin
  if v_store_id is null then raise exception 'User profile/store not found'; end if;
  if v_role not in ('owner', 'seller') then raise exception 'Not allowed'; end if;
  if p_payment_method not in ('cash', 'bank', 'mobile_money', 'mixed') then raise exception 'Invalid payment method'; end if;
  if p_items is null or jsonb_array_length(p_items) = 0 then raise exception 'Sale items are required'; end if;
  if coalesce(p_discount,0) < 0 then raise exception 'Discount cannot be negative'; end if;

  -- Validate and calculate
  for v_item in select * from jsonb_array_elements(p_items) loop
    v_qty := (v_item->>'quantity')::numeric;
    if v_qty <= 0 then raise exception 'Quantity must be positive'; end if;

    select * into v_product from public.products
    where id = (v_item->>'product_id')::uuid
      and store_id = v_store_id
      and is_active = true
    for update;

    if not found then raise exception 'Product not found'; end if;
    if v_product.current_stock < v_qty then
      raise exception 'Insufficient stock for %', v_product.name;
    end if;
    if v_product.selling_price < v_product.minimum_selling_price then
      raise exception 'Selling price below minimum for %', v_product.name;
    end if;

    v_line_total := v_qty * v_product.selling_price;
    v_subtotal := v_subtotal + v_line_total;
  end loop;

  v_total := v_subtotal - coalesce(p_discount,0);
  if v_total < 0 then raise exception 'Discount cannot exceed subtotal'; end if;

  insert into public.sales(id, store_id, seller_id, customer_id, invoice_no, sale_type, subtotal, discount, total_amount, paid_amount, balance_amount, payment_status, approval_status, status, notes)
  values (v_sale_id, v_store_id, auth.uid(), p_customer_id, v_invoice, 'cash', v_subtotal, coalesce(p_discount,0), v_total, v_total, 0, 'paid', 'not_required', 'completed', p_notes);

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_qty := (v_item->>'quantity')::numeric;
    select * into v_product from public.products where id = (v_item->>'product_id')::uuid and store_id = v_store_id for update;
    v_line_total := v_qty * v_product.selling_price;

    insert into public.sale_items(store_id, sale_id, product_id, product_name, unit, quantity, unit_price, total_price)
    values (v_store_id, v_sale_id, v_product.id, v_product.name, v_product.unit, v_qty, v_product.selling_price, v_line_total);

    insert into public.stock_movements(store_id, product_id, movement_type, quantity, previous_stock, new_stock, reference_id, created_by, approval_status, notes)
    values (v_store_id, v_product.id, 'sale', v_qty, v_product.current_stock, v_product.current_stock - v_qty, v_sale_id, auth.uid(), 'not_required', 'Sale ' || v_invoice);

    update public.products
    set current_stock = current_stock - v_qty, updated_at = now()
    where id = v_product.id;
  end loop;

  insert into public.payments(store_id, sale_id, customer_id, seller_id, amount, payment_method, reference_no, notes)
  values (v_store_id, v_sale_id, p_customer_id, auth.uid(), v_total, p_payment_method, p_reference_no, p_notes);

  perform public.log_action('create_cash_sale', 'sales', v_sale_id, null, jsonb_build_object('invoice_no', v_invoice, 'total', v_total));
  return v_sale_id;
end;
$$;

-- =========================
-- RPC: request credit sale owner approval
-- =========================

create or replace function public.request_credit_sale(
  p_customer_id uuid,
  p_items jsonb,
  p_reason text,
  p_discount numeric default 0,
  p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_store_id uuid := public.current_user_store_id();
  v_role text := public.current_user_role();
  v_sale_id uuid := gen_random_uuid();
  v_request_id uuid := gen_random_uuid();
  v_invoice text := public.new_invoice_no();
  v_subtotal numeric(12,2) := 0;
  v_total numeric(12,2) := 0;
  v_item jsonb;
  v_product public.products%rowtype;
  v_qty numeric(12,2);
  v_line_total numeric(12,2);
begin
  if v_store_id is null then raise exception 'User profile/store not found'; end if;
  if v_role not in ('owner', 'seller') then raise exception 'Not allowed'; end if;
  if p_customer_id is null then raise exception 'Credit sale requires customer'; end if;
  if p_reason is null or length(trim(p_reason)) < 3 then raise exception 'Reason is required'; end if;
  if p_items is null or jsonb_array_length(p_items) = 0 then raise exception 'Sale items are required'; end if;

  -- Validate customer belongs to store
  if not exists (select 1 from public.customers where id = p_customer_id and store_id = v_store_id) then
    raise exception 'Customer not found';
  end if;

  -- Validate and calculate, but do not reduce stock yet.
  for v_item in select * from jsonb_array_elements(p_items) loop
    v_qty := (v_item->>'quantity')::numeric;
    if v_qty <= 0 then raise exception 'Quantity must be positive'; end if;
    select * into v_product from public.products
    where id = (v_item->>'product_id')::uuid and store_id = v_store_id and is_active = true;
    if not found then raise exception 'Product not found'; end if;
    if v_product.current_stock < v_qty then raise exception 'Insufficient stock for %', v_product.name; end if;
    v_line_total := v_qty * v_product.selling_price;
    v_subtotal := v_subtotal + v_line_total;
  end loop;

  v_total := v_subtotal - coalesce(p_discount,0);
  if v_total < 0 then raise exception 'Discount cannot exceed subtotal'; end if;

  insert into public.sales(id, store_id, seller_id, customer_id, invoice_no, sale_type, subtotal, discount, total_amount, paid_amount, balance_amount, payment_status, approval_status, status, notes)
  values (v_sale_id, v_store_id, auth.uid(), p_customer_id, v_invoice, 'credit', v_subtotal, coalesce(p_discount,0), v_total, 0, v_total, 'unpaid', 'pending', 'draft', p_notes);

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_qty := (v_item->>'quantity')::numeric;
    select * into v_product from public.products where id = (v_item->>'product_id')::uuid and store_id = v_store_id;
    v_line_total := v_qty * v_product.selling_price;
    insert into public.sale_items(store_id, sale_id, product_id, product_name, unit, quantity, unit_price, total_price)
    values (v_store_id, v_sale_id, v_product.id, v_product.name, v_product.unit, v_qty, v_product.selling_price, v_line_total);
  end loop;

  insert into public.approval_requests(id, store_id, requested_by, request_type, reference_id, amount, reason)
  values (v_request_id, v_store_id, auth.uid(), 'credit_sale', v_sale_id, v_total, p_reason);

  insert into public.notifications(store_id, user_id, title, message, type)
  select v_store_id, id, 'Credit sale approval needed', 'A credit sale of ETB ' || v_total || ' needs approval.', 'approval'
  from public.profiles
  where store_id = v_store_id and role = 'owner' and is_active = true;

  perform public.log_action('request_credit_sale', 'approval_requests', v_request_id, null, jsonb_build_object('sale_id', v_sale_id, 'total', v_total));
  return v_request_id;
end;
$$;

-- =========================
-- RPC: owner approve/reject request
-- =========================

create or replace function public.decide_approval_request(
  p_request_id uuid,
  p_decision text,
  p_owner_comment text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_store_id uuid := public.current_user_store_id();
  v_role text := public.current_user_role();
  v_req public.approval_requests%rowtype;
  v_sale public.sales%rowtype;
  v_item public.sale_items%rowtype;
  v_product public.products%rowtype;
begin
  if v_store_id is null then raise exception 'User profile/store not found'; end if;
  if v_role <> 'owner' then raise exception 'Only owner can approve requests'; end if;
  if p_decision not in ('approved', 'rejected') then raise exception 'Invalid decision'; end if;

  select * into v_req from public.approval_requests
  where id = p_request_id and store_id = v_store_id and status = 'pending'
  for update;
  if not found then raise exception 'Pending request not found'; end if;

  update public.approval_requests
  set status = p_decision, approved_by = auth.uid(), owner_comment = p_owner_comment, decided_at = now()
  where id = p_request_id;

  if v_req.request_type = 'credit_sale' then
    select * into v_sale from public.sales
    where id = v_req.reference_id and store_id = v_store_id and status = 'draft'
    for update;
    if not found then raise exception 'Draft sale not found'; end if;

    if p_decision = 'rejected' then
      update public.sales set approval_status = 'rejected', status = 'cancelled' where id = v_sale.id;
      perform public.log_action('reject_credit_sale', 'sales', v_sale.id, null, jsonb_build_object('request_id', p_request_id));
      return;
    end if;

    -- Approved: validate stock again, reduce stock, create movements, update balance.
    for v_item in select * from public.sale_items where sale_id = v_sale.id loop
      select * into v_product from public.products
      where id = v_item.product_id and store_id = v_store_id
      for update;
      if not found then raise exception 'Product not found'; end if;
      if v_product.current_stock < v_item.quantity then
        raise exception 'Insufficient stock for % at approval time', v_product.name;
      end if;
    end loop;

    for v_item in select * from public.sale_items where sale_id = v_sale.id loop
      select * into v_product from public.products where id = v_item.product_id and store_id = v_store_id for update;
      insert into public.stock_movements(store_id, product_id, movement_type, quantity, previous_stock, new_stock, reference_id, created_by, approval_status, notes)
      values (v_store_id, v_product.id, 'sale', v_item.quantity, v_product.current_stock, v_product.current_stock - v_item.quantity, v_sale.id, v_sale.seller_id, 'approved', 'Credit sale approved ' || v_sale.invoice_no);
      update public.products set current_stock = current_stock - v_item.quantity, updated_at = now() where id = v_product.id;
    end loop;

    update public.sales
    set approval_status = 'approved', status = 'completed'
    where id = v_sale.id;

    update public.customers
    set total_balance = total_balance + v_sale.balance_amount
    where id = v_sale.customer_id and store_id = v_store_id;

    insert into public.notifications(store_id, user_id, title, message, type)
    values (v_store_id, v_sale.seller_id, 'Credit sale approved', 'Your credit sale ' || v_sale.invoice_no || ' was approved.', 'approval_decision');

    perform public.log_action('approve_credit_sale', 'sales', v_sale.id, null, jsonb_build_object('request_id', p_request_id));
  end if;
end;
$$;

-- =========================
-- RPC: seller daily cash closing
-- =========================

create or replace function public.submit_daily_cash_closing(
  p_closing_date date,
  p_actual_cash numeric,
  p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_store_id uuid := public.current_user_store_id();
  v_role text := public.current_user_role();
  v_expected_cash numeric(12,2) := 0;
  v_bank numeric(12,2) := 0;
  v_mobile numeric(12,2) := 0;
  v_credit numeric(12,2) := 0;
  v_id uuid;
begin
  if v_store_id is null then raise exception 'User profile/store not found'; end if;
  if v_role not in ('seller', 'owner') then raise exception 'Not allowed'; end if;
  if p_actual_cash < 0 then raise exception 'Actual cash cannot be negative'; end if;

  select coalesce(sum(amount),0) into v_expected_cash
  from public.payments
  where store_id = v_store_id and seller_id = auth.uid()
    and payment_method = 'cash'
    and created_at::date = p_closing_date;

  select coalesce(sum(amount),0) into v_bank
  from public.payments
  where store_id = v_store_id and seller_id = auth.uid()
    and payment_method = 'bank'
    and created_at::date = p_closing_date;

  select coalesce(sum(amount),0) into v_mobile
  from public.payments
  where store_id = v_store_id and seller_id = auth.uid()
    and payment_method = 'mobile_money'
    and created_at::date = p_closing_date;

  select coalesce(sum(total_amount),0) into v_credit
  from public.sales
  where store_id = v_store_id and seller_id = auth.uid()
    and sale_type = 'credit'
    and status = 'completed'
    and created_at::date = p_closing_date;

  insert into public.daily_cash_closings(store_id, seller_id, closing_date, expected_cash, actual_cash, cash_difference, bank_total, mobile_money_total, credit_sales_total, notes)
  values (v_store_id, auth.uid(), p_closing_date, v_expected_cash, p_actual_cash, p_actual_cash - v_expected_cash, v_bank, v_mobile, v_credit, p_notes)
  on conflict (store_id, seller_id, closing_date)
  do update set
    expected_cash = excluded.expected_cash,
    actual_cash = excluded.actual_cash,
    cash_difference = excluded.cash_difference,
    bank_total = excluded.bank_total,
    mobile_money_total = excluded.mobile_money_total,
    credit_sales_total = excluded.credit_sales_total,
    notes = excluded.notes,
    status = 'submitted',
    created_at = now()
  returning id into v_id;

  insert into public.notifications(store_id, user_id, title, message, type)
  select v_store_id, id, 'Daily cash closing submitted', public.current_user_name() || ' submitted cash closing.', 'cash_closing'
  from public.profiles where store_id = v_store_id and role = 'owner' and is_active = true;

  perform public.log_action('submit_daily_cash_closing', 'daily_cash_closings', v_id, null, jsonb_build_object('date', p_closing_date, 'actual_cash', p_actual_cash, 'expected_cash', v_expected_cash));
  return v_id;
end;
$$;

create or replace function public.review_daily_cash_closing(
  p_closing_id uuid,
  p_status text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_store_id uuid := public.current_user_store_id();
  v_role text := public.current_user_role();
begin
  if v_role <> 'owner' then raise exception 'Only owner can review closings'; end if;
  if p_status not in ('approved', 'rejected') then raise exception 'Invalid status'; end if;
  update public.daily_cash_closings
  set status = p_status, reviewed_by = auth.uid(), reviewed_at = now()
  where id = p_closing_id and store_id = v_store_id;
  if not found then raise exception 'Closing not found'; end if;
  perform public.log_action('review_daily_cash_closing', 'daily_cash_closings', p_closing_id, null, jsonb_build_object('status', p_status));
end;
$$;

-- =========================
-- RPC: dashboard stats
-- =========================

create or replace function public.dashboard_stats()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_store_id uuid := public.current_user_store_id();
  v_today date := now()::date;
  v_json jsonb;
begin
  if v_store_id is null then raise exception 'User profile/store not found'; end if;

  select jsonb_build_object(
    'today_sales', coalesce((select sum(total_amount) from public.sales where store_id = v_store_id and status = 'completed' and created_at::date = v_today),0),
    'today_cash', coalesce((select sum(amount) from public.payments where store_id = v_store_id and payment_method='cash' and created_at::date = v_today),0),
    'today_bank', coalesce((select sum(amount) from public.payments where store_id = v_store_id and payment_method='bank' and created_at::date = v_today),0),
    'today_mobile_money', coalesce((select sum(amount) from public.payments where store_id = v_store_id and payment_method='mobile_money' and created_at::date = v_today),0),
    'today_credit', coalesce((select sum(total_amount) from public.sales where store_id = v_store_id and sale_type='credit' and status='completed' and created_at::date = v_today),0),
    'pending_approvals', coalesce((select count(*) from public.approval_requests where store_id = v_store_id and status='pending'),0),
    'low_stock_items', coalesce((select count(*) from public.products where store_id = v_store_id and is_active=true and current_stock <= minimum_stock),0),
    'customer_debt', coalesce((select sum(total_balance) from public.customers where store_id = v_store_id),0)
  ) into v_json;

  return v_json;
end;
$$;

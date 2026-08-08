begin;

select plan(30);

-- Isolated fixture data. The entire pgTAP file is rolled back by the test run.
insert into public.stores (id, name, currency)
values
  ('10000000-0000-0000-0000-000000000001', 'PR31 Store A', 'ETB'),
  ('20000000-0000-0000-0000-000000000002', 'PR31 Store B', 'ETB')
on conflict (id) do nothing;

insert into auth.users (id, email, raw_user_meta_data)
values
  ('11111111-1111-4111-8111-111111111111', 'pr31-owner-a@example.test', '{}'::jsonb),
  ('11111111-2222-4222-8222-222222222222', 'pr31-seller-a@example.test', '{}'::jsonb),
  ('22222222-1111-4111-8111-111111111111', 'pr31-owner-b@example.test', '{}'::jsonb)
on conflict (id) do nothing;

insert into public.profiles (id, store_id, full_name, role)
values
  ('11111111-1111-4111-8111-111111111111', '10000000-0000-0000-0000-000000000001', 'PR31 Owner A', 'owner'),
  ('11111111-2222-4222-8222-222222222222', '10000000-0000-0000-0000-000000000001', 'PR31 Seller A', 'seller'),
  ('22222222-1111-4111-8111-111111111111', '20000000-0000-0000-0000-000000000002', 'PR31 Owner B', 'owner')
on conflict (id) do nothing;

insert into public.products (
  id, store_id, name, unit, buying_price, selling_price,
  minimum_selling_price, current_stock, minimum_stock
)
values (
  'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  '10000000-0000-0000-0000-000000000001',
  'PR31 Test Product', 'piece', 40, 60, 50, 10, 1
)
on conflict (id) do nothing;

insert into public.customers (id, store_id, name, total_balance)
values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '10000000-0000-0000-0000-000000000001', 'PR31 Customer A', 0),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', '20000000-0000-0000-0000-000000000002', 'PR31 Customer B', 0)
on conflict (id) do nothing;

-- Column privilege hardening from migration 028.
select ok(
  not has_column_privilege('authenticated', 'public.customers', 'total_balance', 'INSERT'),
  'authenticated cannot insert customers.total_balance'
);
select ok(
  not has_column_privilege('authenticated', 'public.customers', 'total_balance', 'UPDATE'),
  'authenticated cannot update customers.total_balance'
);
select ok(
  not has_column_privilege('authenticated', 'public.suppliers', 'total_balance', 'INSERT'),
  'authenticated cannot insert suppliers.total_balance'
);
select ok(
  not has_column_privilege('authenticated', 'public.suppliers', 'total_balance', 'UPDATE'),
  'authenticated cannot update suppliers.total_balance'
);
select ok(
  has_column_privilege('authenticated', 'public.customers', 'name', 'INSERT'),
  'authenticated retains legitimate customer-name insert privilege'
);
select ok(
  has_column_privilege('authenticated', 'public.customers', 'credit_limit', 'UPDATE'),
  'authenticated retains customer credit-control update privilege subject to RLS'
);
select ok(
  has_column_privilege('authenticated', 'public.suppliers', 'name', 'INSERT'),
  'authenticated retains legitimate supplier-name insert privilege'
);
select ok(
  has_column_privilege('authenticated', 'public.suppliers', 'updated_at', 'UPDATE'),
  'authenticated retains supplier updated_at update privilege used by the client'
);
select ok(
  not has_column_privilege('authenticated', 'public.suppliers', 'store_id', 'INSERT'),
  'authenticated cannot choose supplier.store_id directly'
);
select ok(
  exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'suppliers'
      and column_name = 'store_id'
      and column_default ilike '%current_user_store_id%'
  ),
  'supplier.store_id is resolved by the authenticated-store default'
);

-- RLS and trusted financial functions must remain enabled/definer-based.
select ok(
  (select relrowsecurity from pg_class where oid = 'public.customers'::regclass),
  'customers RLS is enabled'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.suppliers'::regclass),
  'suppliers RLS is enabled'
);
select ok(
  exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'record_purchase_v2'
      and p.prosecdef
      and pg_get_userbyid(p.proowner) = 'postgres'
  ),
  'record_purchase_v2 remains a postgres-owned SECURITY DEFINER function'
);
select ok(
  exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'record_customer_payment_v2'
      and p.prosecdef
      and pg_get_userbyid(p.proowner) = 'postgres'
  ),
  'record_customer_payment_v2 remains a postgres-owned SECURITY DEFINER function'
);

-- Owner A: legitimate direct customer/supplier edits work, aggregate tampering fails.
select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
set local role authenticated;

select lives_ok(
  $$insert into public.customers (store_id, name, phone, location, notes)
    values ('10000000-0000-0000-0000-000000000001', 'PR31 Owner Customer', '0900000000', 'Jigjiga', 'test')$$,
  'owner can create a same-store customer using allowed columns'
);
select throws_ok(
  $$insert into public.customers (store_id, name, total_balance)
    values ('10000000-0000-0000-0000-000000000001', 'Tampered Customer', 999)$$,
  '42501', null,
  'client cannot set customer aggregate balance on insert'
);
select throws_ok(
  $$insert into public.customers (store_id, name)
    values ('20000000-0000-0000-0000-000000000002', 'Cross Store Customer')$$,
  '42501', null,
  'customer insert cannot cross store boundaries'
);
select lives_ok(
  $$update public.customers
      set notes = 'owner edit', credit_limit = 5000, credit_days = 30, credit_blocked = false
    where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'$$,
  'owner can update legitimate customer fields'
);
select throws_ok(
  $$update public.customers
      set total_balance = 999
    where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'$$,
  '42501', null,
  'client cannot modify customer aggregate balance on update'
);
select lives_ok(
  $$insert into public.suppliers (name, phone, address, contact_person, notes)
    values ('PR31 Supplier A', '0911000000', 'Jigjiga', 'Test Contact', 'test')$$,
  'owner can create a supplier without client-supplied store_id'
);
select results_eq(
  $$select store_id from public.suppliers where name = 'PR31 Supplier A'$$,
  ARRAY['10000000-0000-0000-0000-000000000001'::uuid],
  'supplier default assigns the authenticated owner store'
);
select throws_ok(
  $$insert into public.suppliers (name, total_balance)
    values ('Tampered Supplier', 999)$$,
  '42501', null,
  'client cannot set supplier aggregate balance on insert'
);
select throws_ok(
  $$update public.suppliers
      set total_balance = 999
    where name = 'PR31 Supplier A'$$,
  '42501', null,
  'client cannot modify supplier aggregate balance on update'
);
select lives_ok(
  $$update public.suppliers
      set notes = 'owner edit', updated_at = now()
    where name = 'PR31 Supplier A'$$,
  'owner can update legitimate supplier fields'
);

-- SECURITY DEFINER purchase RPC must still be able to maintain supplier balance.
select lives_ok(
  $$select public.record_purchase_v2(
      '[{"product_id":"cccccccc-cccc-4ccc-8ccc-cccccccccccc","quantity":2,"unit_cost":50}]'::jsonb,
      (select id from public.suppliers where name = 'PR31 Supplier A'),
      'PR31-PO-1', current_date, 0, null, 'privilege test', 'pr31-purchase-1'
    )$$,
  'trusted purchase RPC still works after column-level privilege hardening'
);
select results_eq(
  $$select total_balance from public.suppliers where name = 'PR31 Supplier A'$$,
  ARRAY[100::numeric],
  'trusted purchase RPC can update server-owned supplier balance'
);

reset role;

-- Seller A: customer creation remains allowed, customer edits and supplier creation remain RLS-restricted.
select set_config('request.jwt.claim.sub', '11111111-2222-4222-8222-222222222222', true);
set local role authenticated;

select lives_ok(
  $$insert into public.customers (store_id, name)
    values ('10000000-0000-0000-0000-000000000001', 'PR31 Seller Customer')$$,
  'seller can create a customer in their own store'
);
select results_eq(
  $$update public.customers
      set notes = 'seller should not edit'
    where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
    returning id$$,
  ARRAY[]::uuid[],
  'seller cannot update customers because owner/manager RLS filters the row'
);
select throws_ok(
  $$insert into public.suppliers (name) values ('Seller Supplier')$$,
  '42501', null,
  'seller cannot create suppliers'
);
select results_eq(
  $$select count(*) from public.customers
    where store_id = '20000000-0000-0000-0000-000000000002'$$,
  ARRAY[0::bigint],
  'cross-store customer rows are invisible under RLS'
);

reset role;

select * from finish();
rollback;

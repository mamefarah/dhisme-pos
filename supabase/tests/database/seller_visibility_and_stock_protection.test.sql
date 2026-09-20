begin;

select plan(18);

-- Isolated fixture data. The entire pgTAP file is rolled back by the test run.
insert into public.stores (id, name, currency)
values ('30000000-0000-0000-0000-000000000001', 'PR38 Store', 'ETB')
on conflict (id) do nothing;

insert into auth.users (id, email, raw_user_meta_data)
values
  ('33333333-1111-4111-8111-111111111111', 'pr38-owner@example.test', '{}'::jsonb),
  ('33333333-2222-4222-8222-222222222222', 'pr38-seller-a@example.test', '{}'::jsonb),
  ('33333333-3333-4333-8333-333333333333', 'pr38-seller-b@example.test', '{}'::jsonb)
on conflict (id) do nothing;

insert into public.profiles (id, store_id, full_name, role)
values
  ('33333333-1111-4111-8111-111111111111', '30000000-0000-0000-0000-000000000001', 'PR38 Owner', 'owner'),
  ('33333333-2222-4222-8222-222222222222', '30000000-0000-0000-0000-000000000001', 'PR38 Seller A', 'seller'),
  ('33333333-3333-4333-8333-333333333333', '30000000-0000-0000-0000-000000000001', 'PR38 Seller B', 'seller')
on conflict (id) do nothing;

insert into public.products (
  id, store_id, name, unit, buying_price, selling_price,
  minimum_selling_price, current_stock, minimum_stock
)
values (
  'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
  '30000000-0000-0000-0000-000000000001',
  'PR38 Test Product', 'piece', 40, 60, 50, 20, 5
)
on conflict (id) do nothing;

insert into public.customers (id, store_id, name, total_balance)
values ('44444444-4444-4444-8444-444444444444', '30000000-0000-0000-0000-000000000001', 'PR38 Customer', 0)
on conflict (id) do nothing;

-- One row per table attributable to Seller A, one to Seller B.
insert into public.payments (id, store_id, seller_id, amount, payment_method)
values
  ('50000000-0000-4000-8000-00000000000a', '30000000-0000-0000-0000-000000000001', '33333333-2222-4222-8222-222222222222', 1000, 'cash'),
  ('50000000-0000-4000-8000-00000000000b', '30000000-0000-0000-0000-000000000001', '33333333-3333-4333-8333-333333333333', 2000, 'cash')
on conflict (id) do nothing;

insert into public.stock_movements (id, store_id, product_id, movement_type, quantity, previous_stock, new_stock, created_by)
values
  ('51000000-0000-4000-8000-00000000000a', '30000000-0000-0000-0000-000000000001', 'dddddddd-dddd-4ddd-8ddd-dddddddddddd', 'adjustment_in', 1, 20, 21, '33333333-2222-4222-8222-222222222222'),
  ('51000000-0000-4000-8000-00000000000b', '30000000-0000-0000-0000-000000000001', 'dddddddd-dddd-4ddd-8ddd-dddddddddddd', 'adjustment_in', 1, 21, 22, '33333333-3333-4333-8333-333333333333')
on conflict (id) do nothing;

insert into public.approval_requests (id, store_id, requested_by, request_type, reason)
values
  ('52000000-0000-4000-8000-00000000000a', '30000000-0000-0000-0000-000000000001', '33333333-2222-4222-8222-222222222222', 'credit_sale', 'PR38 Seller A request'),
  ('52000000-0000-4000-8000-00000000000b', '30000000-0000-0000-0000-000000000001', '33333333-3333-4333-8333-333333333333', 'credit_sale', 'PR38 Seller B request')
on conflict (id) do nothing;

insert into public.daily_cash_closings (id, store_id, seller_id, closing_date, actual_cash)
values
  ('53000000-0000-4000-8000-00000000000a', '30000000-0000-0000-0000-000000000001', '33333333-2222-4222-8222-222222222222', current_date, 1000),
  ('53000000-0000-4000-8000-00000000000b', '30000000-0000-0000-0000-000000000001', '33333333-3333-4333-8333-333333333333', current_date, 2000)
on conflict (id) do nothing;

insert into public.customer_payments (id, store_id, customer_id, received_by, amount, payment_method)
values
  ('54000000-0000-4000-8000-00000000000a', '30000000-0000-0000-0000-000000000001', '44444444-4444-4444-8444-444444444444', '33333333-2222-4222-8222-222222222222', 500, 'cash'),
  ('54000000-0000-4000-8000-00000000000b', '30000000-0000-0000-0000-000000000001', '44444444-4444-4444-8444-444444444444', '33333333-3333-4333-8333-333333333333', 700, 'cash')
on conflict (id) do nothing;

-- ─── Seller A: can see only their own rows on each of the five tables ────────
select set_config('request.jwt.claim.sub', '33333333-2222-4222-8222-222222222222', true);
set local role authenticated;

-- 1. payments
select results_eq(
  $$select id from public.payments where store_id = '30000000-0000-0000-0000-000000000001' order by id$$,
  ARRAY['50000000-0000-4000-8000-00000000000a'::uuid],
  'seller cannot SELECT another seller''s payments'
);

-- 2. stock_movements
select results_eq(
  $$select id from public.stock_movements where product_id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd' order by id$$,
  ARRAY['51000000-0000-4000-8000-00000000000a'::uuid],
  'seller cannot SELECT another seller''s stock_movements'
);

-- 3. approval_requests
select results_eq(
  $$select id from public.approval_requests where store_id = '30000000-0000-0000-0000-000000000001' order by id$$,
  ARRAY['52000000-0000-4000-8000-00000000000a'::uuid],
  'seller cannot SELECT another seller''s approval_requests'
);

-- 4. daily_cash_closings
select results_eq(
  $$select id from public.daily_cash_closings where store_id = '30000000-0000-0000-0000-000000000001' order by id$$,
  ARRAY['53000000-0000-4000-8000-00000000000a'::uuid],
  'seller cannot SELECT another seller''s daily_cash_closings'
);

-- 5. customer_payments
select results_eq(
  $$select id from public.customer_payments where store_id = '30000000-0000-0000-0000-000000000001' order by id$$,
  ARRAY['54000000-0000-4000-8000-00000000000a'::uuid],
  'seller cannot SELECT another seller''s customer_payments'
);

-- 9. seller cannot invoke adjust_stock successfully
select throws_ok(
  $$select public.adjust_stock('dddddddd-dddd-4ddd-8ddd-dddddddddddd', 1, 'seller attempt')$$,
  'P0001', 'Only owners and managers can adjust stock',
  'seller cannot invoke adjust_stock successfully'
);

reset role;

-- ─── Owner: retains store-wide visibility across all five tables ────────────
-- Note: production's profiles_role_check also allows 'manager' (confirmed live
-- on 2026-09-20), but no committed migration adds 'manager' to the local
-- constraint (001_init.sql:24 only allows 'owner'/'seller'), so a 'manager'
-- profile cannot be created against this locally-rebuilt schema yet. Owner is
-- used here to exercise the same `current_user_role() IN ('owner','manager')`
-- branch; add a 'manager' fixture once that drift-capture migration lands.
select set_config('request.jwt.claim.sub', '33333333-1111-4111-8111-111111111111', true);
set local role authenticated;

-- 6. owner retains store-wide visibility (checked across all five tables)
select results_eq(
  $$select count(*) from public.payments where store_id = '30000000-0000-0000-0000-000000000001'$$,
  ARRAY[2::bigint],
  'owner/manager retain store-wide visibility on payments'
);
select results_eq(
  $$select count(*) from public.stock_movements where product_id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd'$$,
  ARRAY[2::bigint],
  'owner/manager retain store-wide visibility on stock_movements'
);
select results_eq(
  $$select count(*) from public.approval_requests where store_id = '30000000-0000-0000-0000-000000000001'$$,
  ARRAY[2::bigint],
  'owner/manager retain store-wide visibility on approval_requests'
);
select results_eq(
  $$select count(*) from public.daily_cash_closings where store_id = '30000000-0000-0000-0000-000000000001'$$,
  ARRAY[2::bigint],
  'owner/manager retain store-wide visibility on daily_cash_closings'
);
select results_eq(
  $$select count(*) from public.customer_payments where store_id = '30000000-0000-0000-0000-000000000001'$$,
  ARRAY[2::bigint],
  'owner/manager retain store-wide visibility on customer_payments'
);

-- 10. owner/manager can invoke adjust_stock
select lives_ok(
  $$select public.adjust_stock('dddddddd-dddd-4ddd-8ddd-dddddddddddd', 5, 'owner correction')$$,
  'owner/manager can invoke adjust_stock'
);
select results_eq(
  $$select current_stock from public.products where id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd'$$,
  ARRAY[25::numeric],
  'adjust_stock by owner updates product current_stock'
);

reset role;

-- ─── Column-privilege protection on products (role-independent grants) ──────

-- 7. authenticated cannot UPDATE products.current_stock
select ok(
  not has_column_privilege('authenticated', 'public.products', 'current_stock', 'UPDATE'),
  'authenticated cannot UPDATE products.current_stock'
);

-- 8. authenticated can UPDATE permitted product columns including notes
select ok(
  has_column_privilege('authenticated', 'public.products', 'notes', 'UPDATE'),
  'authenticated can UPDATE products.notes'
);
select ok(
  has_column_privilege('authenticated', 'public.products', 'selling_price', 'UPDATE'),
  'authenticated can UPDATE products.selling_price'
);

-- End-to-end confirmation that a permitted column update actually works under RLS.
select set_config('request.jwt.claim.sub', '33333333-1111-4111-8111-111111111111', true);
set local role authenticated;

select lives_ok(
  $$update public.products set notes = 'owner edit' where id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd'$$,
  'authenticated (owner) can UPDATE products.notes end-to-end'
);
select throws_ok(
  $$update public.products set current_stock = 999 where id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd'$$,
  '42501', null,
  'authenticated (owner) cannot UPDATE products.current_stock end-to-end'
);

reset role;

select * from finish();
rollback;

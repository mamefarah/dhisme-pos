-- Persistent fixture used only by the isolated CI restore drill.
-- The source local database is destroyed after the encrypted backup is created.

insert into public.stores (id, name, currency)
values ('90000000-0000-0000-0000-000000000001', 'Restore Drill Store', 'ETB')
on conflict (id) do nothing;

insert into auth.users (id, email, raw_user_meta_data)
values ('91111111-1111-4111-8111-111111111111', 'restore-owner@example.test', '{}'::jsonb)
on conflict (id) do nothing;

insert into public.profiles (id, store_id, full_name, role)
values (
  '91111111-1111-4111-8111-111111111111',
  '90000000-0000-0000-0000-000000000001',
  'Restore Drill Owner',
  'owner'
)
on conflict (id) do nothing;

insert into public.categories (id, store_id, name)
values (
  '92222222-2222-4222-8222-222222222222',
  '90000000-0000-0000-0000-000000000001',
  'Restore Drill Category'
)
on conflict (id) do nothing;

insert into public.products (
  id, store_id, category_id, name, unit, buying_price, selling_price,
  minimum_selling_price, current_stock, minimum_stock
)
values (
  '93333333-3333-4333-8333-333333333333',
  '90000000-0000-0000-0000-000000000001',
  '92222222-2222-4222-8222-222222222222',
  'Restore Drill Product', 'piece', 40, 80, 60, 5, 1
)
on conflict (id) do nothing;

insert into public.customers (
  id, store_id, name, total_balance, credit_limit, credit_days
)
values (
  '94444444-4444-4444-8444-444444444444',
  '90000000-0000-0000-0000-000000000001',
  'Restore Drill Customer', 0, 10000, 30
)
on conflict (id) do nothing;

-- Deterministic reference row for purchase/restore comparison. Authenticated
-- supplier-creation privileges are separately exercised by the 30-test pgTAP
-- security suite; transaction flows below run as the actual Owner role.
insert into public.suppliers (
  id, store_id, name, phone, address, contact_person, notes
)
values (
  '95555555-5555-4555-8555-555555555555',
  '90000000-0000-0000-0000-000000000001',
  'Restore Drill Supplier', '0911000000', 'Jigjiga', 'Restore Contact', 'restore fixture'
)
on conflict (id) do nothing;

select set_config('request.jwt.claim.sub', '91111111-1111-4111-8111-111111111111', false);
set role authenticated;

select public.record_purchase_v2(
  '[{"product_id":"93333333-3333-4333-8333-333333333333","quantity":3,"unit_cost":50}]'::jsonb,
  '95555555-5555-4555-8555-555555555555'::uuid,
  'RESTORE-PO-1', current_date, 50, 'cash', 'restore fixture purchase',
  'restore-purchase-0001'
) as purchase_id \gset

select public.create_cash_sale_v2(
  '94444444-4444-4444-8444-444444444444'::uuid,
  '[{"product_id":"93333333-3333-4333-8333-333333333333","quantity":1}]'::jsonb,
  '[{"payment_method":"cash","amount":80}]'::jsonb,
  0, 'restore fixture cash sale', 'restore-cash-sale-0001'
) as cash_sale_id \gset

select id as cash_sale_item_id
from public.sale_items
where sale_id = :'cash_sale_id'::uuid
limit 1 \gset

select public.record_return_v2(
  :'cash_sale_id'::uuid,
  jsonb_build_array(jsonb_build_object('sale_item_id', :'cash_sale_item_id'::uuid, 'quantity', 0.5)),
  'cash', 'restore fixture return', 'restore-return-0001'
);

select public.request_credit_sale_v2(
  '94444444-4444-4444-8444-444444444444'::uuid,
  '[{"product_id":"93333333-3333-4333-8333-333333333333","quantity":1}]'::jsonb,
  'restore drill credit', 0, 'restore fixture credit sale',
  'restore-credit-request-0001'
) as request_id \gset

select public.decide_approval_request(
  :'request_id'::uuid, 'approved', 'restore drill approval'
);

select public.record_customer_payment_v2(
  '94444444-4444-4444-8444-444444444444'::uuid,
  20, 'bank', 'RESTORE-CUST-PAY-1', 'restore fixture customer payment',
  'restore-customer-payment-0001'
);

select public.record_expense_v2(
  'Restore Drill Expense', 10, 'cash', current_date,
  'RESTORE-EXP-1', 'restore fixture expense', 'restore-expense-0001'
);

select public.record_cash_adjustment_v2(
  'opening_float', 25, current_date,
  'RESTORE-FLOAT-1', 'restore fixture opening float', 'restore-adjustment-0001'
);

select public.submit_daily_cash_closing_v2(
  current_date,
  55,
  'restore fixture closing'
);

reset role;
reset request.jwt.claim.sub;

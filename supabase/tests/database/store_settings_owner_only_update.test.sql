begin;

select plan(16);

-- Isolated fixture data. The entire pgTAP file is rolled back by the test run.
insert into public.stores (id, name, currency)
values
  ('39990000-0000-0000-0000-000000000001', 'PR42 Store A', 'ETB'),
  ('39990000-0000-0000-0000-000000000002', 'PR42 Store B (other store)', 'ETB')
on conflict (id) do nothing;

insert into auth.users (id, email, raw_user_meta_data)
values
  ('39991111-1111-4111-8111-111111111111', 'pr42-owner@example.test', '{}'::jsonb),
  ('39991111-2222-4222-8222-222222222222', 'pr42-manager@example.test', '{}'::jsonb),
  ('39991111-3333-4333-8333-333333333333', 'pr42-seller@example.test', '{}'::jsonb)
on conflict (id) do nothing;

insert into public.profiles (id, store_id, full_name, role)
values
  ('39991111-1111-4111-8111-111111111111', '39990000-0000-0000-0000-000000000001', 'PR42 Owner', 'owner'),
  ('39991111-2222-4222-8222-222222222222', '39990000-0000-0000-0000-000000000001', 'PR42 Manager', 'manager'),
  ('39991111-3333-4333-8333-333333333333', '39990000-0000-0000-0000-000000000001', 'PR42 Seller', 'seller')
on conflict (id) do nothing;

-- ─── Owner: can update own store identity ────────────────────────────────
select set_config('request.jwt.claim.sub', '39991111-1111-4111-8111-111111111111', true);
set local role authenticated;

select lives_ok(
  $$update public.stores set name = 'PR42 Store A (renamed by owner)' where id = '39990000-0000-0000-0000-000000000001'$$,
  '1. owner can update own store identity'
);

select results_eq(
  $$select name from public.stores where id = '39990000-0000-0000-0000-000000000001'$$,
  ARRAY['PR42 Store A (renamed by owner)'::text],
  '2. owner store update is actually persisted'
);

-- Owner cannot reach across stores: id must equal current_user_store_id().
select is_empty(
  $$update public.stores set name = 'Hijacked by owner A' where id = '39990000-0000-0000-0000-000000000002' returning id$$,
  '5. owner cannot update another store (cross-store UPDATE denied, correct store scoping)'
);

reset role;

-- ─── Manager: cannot update store identity ───────────────────────────────
select set_config('request.jwt.claim.sub', '39991111-2222-4222-8222-222222222222', true);
set local role authenticated;

select is_empty(
  $$update public.stores set name = 'Manager attempt' where id = '39990000-0000-0000-0000-000000000001' returning id$$,
  '3. manager cannot update own store identity (RLS denies, zero rows)'
);

select results_eq(
  $$select count(*) from public.stores where id = '39990000-0000-0000-0000-000000000001'$$,
  ARRAY[1::bigint],
  '6. store SELECT still works for manager after adding the UPDATE policy'
);

select throws_ok(
  $$select public.create_store_invite('manager')$$,
  'P0001', 'Only owners can create invite codes',
  '8. create_store_invite remains owner-only (manager denied)'
);

select throws_ok(
  $$select public.decide_approval_request(gen_random_uuid(), 'approved')$$,
  'P0001', 'Only owner can approve requests',
  '10. decide_approval_request remains owner-only (manager denied)'
);

select throws_ok(
  $$select public.review_daily_cash_closing(gen_random_uuid(), 'approved')$$,
  'P0001', 'Only owner can review closings',
  '11. review_daily_cash_closing remains owner-only (manager denied)'
);

select lives_ok(
  $$select public.sales_summary_v2()$$,
  '12. manager report RPC authorization remains intact: sales_summary_v2'
);
select lives_ok(
  $$select public.financial_summary_v2(now() - interval '30 days', now())$$,
  '13. manager report RPC authorization remains intact: financial_summary_v2'
);
select lives_ok(
  $$select public.top_products_v2()$$,
  '14. manager report RPC authorization remains intact: top_products_v2'
);
select lives_ok(
  $$select public.profit_summary_v2()$$,
  '15. manager report RPC authorization remains intact: profit_summary_v2'
);

reset role;

-- ─── Seller: cannot update store identity, cannot reach owner/manager RPCs ──
select set_config('request.jwt.claim.sub', '39991111-3333-4333-8333-333333333333', true);
set local role authenticated;

select is_empty(
  $$update public.stores set name = 'Seller attempt' where id = '39990000-0000-0000-0000-000000000001' returning id$$,
  '4. seller cannot update store identity (RLS denies, zero rows)'
);

select results_eq(
  $$select count(*) from public.stores where id = '39990000-0000-0000-0000-000000000001'$$,
  ARRAY[1::bigint],
  '7. store SELECT still works for seller after adding the UPDATE policy'
);

select throws_ok(
  $$select public.create_store_invite('seller')$$,
  'P0001', 'Only owners can create invite codes',
  '9. create_store_invite remains owner-only (seller denied)'
);

select throws_ok(
  $$select public.sales_summary_v2()$$,
  'P0001', 'Reports require owner or manager role',
  '16. seller report RPC access remains denied: sales_summary_v2'
);

reset role;

select * from finish();
rollback;

begin;

select plan(9);

-- Isolated fixture data. The entire pgTAP file is rolled back by the test run.
insert into public.stores (id, name, currency)
values ('39992222-0000-0000-0000-000000000001', 'PR43 Invite Store', 'ETB')
on conflict (id) do nothing;

insert into auth.users (id, email, raw_user_meta_data)
values
  ('39992222-1111-4111-8111-111111111111', 'pr43-owner@example.test', '{}'::jsonb),
  ('39992222-2222-4222-8222-222222222222', 'pr43-new-seller@example.test', '{}'::jsonb),
  ('39992222-3333-4333-8333-333333333333', 'pr43-existing-profile@example.test', '{}'::jsonb),
  ('39992222-4444-4444-8444-444444444444', 'pr43-second-newcomer@example.test', '{}'::jsonb)
on conflict (id) do nothing;

insert into public.profiles (id, store_id, full_name, role)
values
  ('39992222-1111-4111-8111-111111111111', '39992222-0000-0000-0000-000000000001', 'PR43 Owner', 'owner'),
  ('39992222-3333-4333-8333-333333333333', '39992222-0000-0000-0000-000000000001', 'PR43 Existing', 'seller')
on conflict (id) do nothing;

-- ─── Owner creates a real invite through the real RPC ────────────────────
select set_config('request.jwt.claim.sub', '39992222-1111-4111-8111-111111111111', true);
set local role authenticated;

create temporary table _pr43_invite as
select public.create_store_invite('seller') as code;

select ok(
  (select length(code) from _pr43_invite) = 8,
  '1. owner creates a real single-use seller invite code via create_store_invite'
);

reset role;

select results_eq(
  $$select store_id, role, used_at, used_by from public.store_invites where code = (select code from _pr43_invite)$$,
  $$select '39992222-0000-0000-0000-000000000001'::uuid, 'seller'::text, null::timestamptz, null::uuid$$,
  '2. invite row is scoped to the creating store, correct role, unused'
);

-- ─── A brand-new authenticated user (no profile yet) redeems the invite ──
select set_config('request.jwt.claim.sub', '39992222-2222-4222-8222-222222222222', true);
set local role authenticated;

select lives_ok(
  $$select public.register_with_invite('PR43 New Seller', (select code from _pr43_invite))$$,
  '3. a brand-new auth user can redeem a valid invite via register_with_invite'
);

reset role;

select results_eq(
  $$select store_id, role, is_active from public.profiles where id = '39992222-2222-4222-8222-222222222222'::uuid$$,
  $$select '39992222-0000-0000-0000-000000000001'::uuid, 'seller'::text, true$$,
  '4. the created profile matches the invite''s store and role, and is active'
);

select ok(
  (select used_at is not null and used_by = '39992222-2222-4222-8222-222222222222'::uuid
   from public.store_invites where code = (select code from _pr43_invite)),
  '5. invite is marked used_at/used_by the redeeming user'
);

-- ─── A user who already has a profile cannot redeem any invite ──────────
select set_config('request.jwt.claim.sub', '39992222-1111-4111-8111-111111111111', true);
set local role authenticated;

create temporary table _pr43_invite2 as
select public.create_store_invite('manager') as code;

reset role;

select set_config('request.jwt.claim.sub', '39992222-3333-4333-8333-333333333333', true);
set local role authenticated;

select throws_ok(
  $$select public.register_with_invite('Second Try', (select code from _pr43_invite2))$$,
  'P0001', 'An account profile already exists for this login.',
  '6. a user who already has a profile cannot redeem another invite'
);

reset role;

-- ─── The remaining tests use a second brand-new user (no profile) so the
--     invite-validity checks themselves are exercised, not the
--     profile-already-exists guard. ────────────────────────────────────────
select set_config('request.jwt.claim.sub', '39992222-4444-4444-8444-444444444444', true);
set local role authenticated;

select throws_ok(
  $$select public.register_with_invite('Reuse Attempt', (select code from _pr43_invite))$$,
  'P0001', 'Invite code is invalid or has expired. Ask the store owner for a new one.',
  '7. a consumed invite code cannot be redeemed by a different new user'
);

select throws_ok(
  $$select public.register_with_invite('Nobody', 'NOTAREALCODE')$$,
  'P0001', 'Invite code is invalid or has expired. Ask the store owner for a new one.',
  '8. an invalid/unknown invite code is rejected'
);

reset role;

-- ─── Expired code ─────────────────────────────────────────────────────────
insert into public.store_invites (store_id, code, role, created_by, expires_at)
values (
  '39992222-0000-0000-0000-000000000001',
  'EXPIRED1',
  'seller',
  '39992222-1111-4111-8111-111111111111',
  now() - interval '1 hour'
)
on conflict (code) do nothing;

select set_config('request.jwt.claim.sub', '39992222-4444-4444-8444-444444444444', true);
set local role authenticated;

select throws_ok(
  $$select public.register_with_invite('Too Late', 'EXPIRED1')$$,
  'P0001', 'Invite code is invalid or has expired. Ask the store owner for a new one.',
  '9. an expired invite code is rejected'
);

reset role;

select * from finish();
rollback;

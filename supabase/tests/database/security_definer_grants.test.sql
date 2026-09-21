begin;

select plan(8);

-- Regression coverage for the SECURITY DEFINER audit: the two genuine
-- internal-only helpers and the audit logger must stay unreachable by
-- normal clients, while the RLS-support helpers and real app RPCs must
-- stay reachable by `authenticated` — a table-level grant check, not a
-- role-impersonation check, since these functions are either invoked
-- internally by other SECURITY DEFINER functions or are the exact thing
-- RLS policies call.

-- ─── Internal-only: must NOT be executable by normal clients ────────────
select ok(
  not has_function_privilege('authenticated', 'private.claim_operation(uuid,text,text,uuid)', 'EXECUTE'),
  '1. private.claim_operation is not directly executable by authenticated'
);
select ok(
  not has_function_privilege('anon', 'private.claim_operation(uuid,text,text,uuid)', 'EXECUTE'),
  '2. private.claim_operation is not directly executable by anon'
);
select ok(
  not has_function_privilege('authenticated', 'private.complete_operation(uuid,uuid)', 'EXECUTE'),
  '3. private.complete_operation is not directly executable by authenticated'
);
select ok(
  not has_function_privilege('authenticated', 'public.log_action(text,text,uuid,jsonb,jsonb)', 'EXECUTE'),
  '4. log_action is not directly executable by authenticated (audit trail cannot be forged by clients)'
);

-- ─── Required exposed surface: must remain executable by authenticated ──
-- (positive controls, so 1-4 are proving something meaningful rather than
-- a database where nothing is executable by anyone)
select ok(
  has_function_privilege('authenticated', 'public.current_user_role()', 'EXECUTE'),
  '5. current_user_role remains executable by authenticated (required by every RLS policy)'
);
select ok(
  has_function_privilege('authenticated', 'public.current_user_store_id()', 'EXECUTE'),
  '6. current_user_store_id remains executable by authenticated (required by every RLS policy)'
);
select ok(
  has_function_privilege('authenticated', 'public.create_cash_sale_v2(uuid,jsonb,jsonb,numeric,text,text)', 'EXECUTE'),
  '7. create_cash_sale_v2 remains executable by authenticated (real app RPC)'
);
select ok(
  has_function_privilege('authenticated', 'public.create_store_invite(text)', 'EXECUTE'),
  '8. create_store_invite remains executable by authenticated (its own role check enforces owner-only)'
);

select * from finish();
rollback;

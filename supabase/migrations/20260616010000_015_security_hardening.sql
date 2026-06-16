-- Phase 15: Security Hardening
--
-- Changes:
--   A. Fix new_invoice_no() missing search_path (flagged by Supabase security advisor)
--   B. Revoke execute on all public functions from anon
--      Business RPCs must never be callable by unauthenticated requests.
--   C. Grant only what is needed to authenticated role
--   D. Helper functions used in RLS policies remain accessible to anon
--      (needed for policy evaluation on unauthenticated requests)
--
-- How to run:
--   Supabase CLI:       supabase db push
--   Supabase Dashboard: SQL Editor → paste → Run

-- ─── A. Fix new_invoice_no() ─────────────────────────────────────────────────
-- Was missing both SECURITY DEFINER and SET search_path.
-- Since this function is called only from other SECURITY DEFINER RPCs,
-- it does not need to be callable by any user role.
create or replace function public.new_invoice_no()
returns text
language sql
security definer
set search_path = public
as $$
  select 'INV-' || to_char(now(), 'YYYYMMDD-HH24MISS') || '-' || upper(substring(gen_random_uuid()::text, 1, 6))
$$;

-- ─── B. Revoke execute from anon on all public functions ──────────────────────
-- In PostgreSQL, functions are executable by PUBLIC (including anon) by default.
-- We explicitly revoke this so that unauthenticated callers cannot invoke any
-- business logic, even if they somehow obtain the Supabase anon key.
revoke execute on all functions in schema public from anon;

-- ─── C. Restore access to helper functions for RLS policy evaluation ──────────
-- RLS policies on all tables call current_user_store_id() and current_user_role().
-- These must remain executable by all roles so that row-level security evaluation
-- works correctly for both anon and authenticated sessions.
grant execute on function public.current_user_store_id() to anon, authenticated;
grant execute on function public.current_user_role()     to anon, authenticated;
grant execute on function public.current_user_name()     to anon, authenticated;

-- ─── D. Grant business RPCs to authenticated only ─────────────────────────────
-- Each function still enforces its own role check internally (SECURITY DEFINER).
-- This grant only controls who can invoke the function via PostgREST/client.

-- Registration (called right after Supabase signup while the user is authenticated)
grant execute on function public.register_owner(text, text, text, text, text)     to authenticated;
grant execute on function public.register_with_invite(text, text, text)            to authenticated;

-- POS sales
grant execute on function public.create_cash_sale(uuid, jsonb, text, text, numeric, text)  to authenticated;
grant execute on function public.request_credit_sale(uuid, jsonb, text, numeric, text)      to authenticated;

-- Owner decision-making
grant execute on function public.decide_approval_request(uuid, text, text)  to authenticated;
grant execute on function public.review_daily_cash_closing(uuid, text)       to authenticated;

-- Seller daily close
grant execute on function public.submit_daily_cash_closing(date, numeric, text) to authenticated;

-- Inventory operations
grant execute on function public.record_purchase(jsonb, uuid, text, date, text, text) to authenticated;
grant execute on function public.adjust_stock(uuid, numeric, text)                     to authenticated;

-- Customer debt
grant execute on function public.record_customer_payment(uuid, numeric, text, text, text) to authenticated;

-- Dashboard & invite management
grant execute on function public.dashboard_stats()      to authenticated;
grant execute on function public.create_store_invite(text) to authenticated;

-- NOTE: log_action() and new_invoice_no() are intentionally NOT granted to any
-- user role. They are called only from within SECURITY DEFINER functions
-- (which run as the function owner), so no user-level grant is required.

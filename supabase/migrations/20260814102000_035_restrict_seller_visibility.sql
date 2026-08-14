-- Sellers can currently read every other seller's payments, stock movements,
-- pending approval requests (including credit-sale reasons/amounts), daily
-- cash closings, and customer payments — these five tables kept the original
-- 001_init.sql store-wide SELECT policy. Only sales/sale_items got a
-- seller-scoped fix (see 20260616030000_017_rls_sales_restriction.sql).
--
-- This applies the same pattern used there: owners/managers keep full
-- store-wide visibility; sellers are scoped to rows they created.
--
-- How to run:
--   Supabase CLI:       supabase db push
--   Supabase Dashboard: SQL Editor -> paste this file -> Run

-- ─── payments ──────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "payments read" ON public.payments;

CREATE POLICY "payments read"
  ON public.payments FOR SELECT TO authenticated
  USING (
    store_id = public.current_user_store_id()
    AND (
      public.current_user_role() IN ('owner', 'manager')
      OR seller_id = auth.uid()
    )
  );

-- ─── stock_movements ───────────────────────────────────────────────────────
DROP POLICY IF EXISTS "stock movements read" ON public.stock_movements;

CREATE POLICY "stock movements read"
  ON public.stock_movements FOR SELECT TO authenticated
  USING (
    store_id = public.current_user_store_id()
    AND (
      public.current_user_role() IN ('owner', 'manager')
      OR created_by = auth.uid()
    )
  );

-- ─── approval_requests ─────────────────────────────────────────────────────
DROP POLICY IF EXISTS "approvals read" ON public.approval_requests;

CREATE POLICY "approvals read"
  ON public.approval_requests FOR SELECT TO authenticated
  USING (
    store_id = public.current_user_store_id()
    AND (
      public.current_user_role() IN ('owner', 'manager')
      OR requested_by = auth.uid()
    )
  );

-- ─── daily_cash_closings ───────────────────────────────────────────────────
DROP POLICY IF EXISTS "closings read" ON public.daily_cash_closings;

CREATE POLICY "closings read"
  ON public.daily_cash_closings FOR SELECT TO authenticated
  USING (
    store_id = public.current_user_store_id()
    AND (
      public.current_user_role() IN ('owner', 'manager')
      OR seller_id = auth.uid()
    )
  );

-- ─── customer_payments ─────────────────────────────────────────────────────
DROP POLICY IF EXISTS "customer_payments select store" ON public.customer_payments;

CREATE POLICY "customer_payments select store"
  ON public.customer_payments FOR SELECT TO authenticated
  USING (
    store_id = public.current_user_store_id()
    AND (
      public.current_user_role() IN ('owner', 'manager')
      OR received_by = auth.uid()
    )
  );

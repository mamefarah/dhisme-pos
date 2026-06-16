-- Phase 17: RLS Sales Restriction
--
-- Sellers may only read their own sales and sale_items.
-- Owners and managers continue to see all store sales.
--
-- Change from 001_init.sql:
--   "sales read"      — was: store_id = current_user_store_id()  (all users see all sales)
--   "sale items read" — was: same
--   Now both add a role-based OR condition so sellers are scoped to seller_id = auth.uid().
--
-- How to run:
--   Supabase CLI:       supabase db push
--   Supabase Dashboard: SQL Editor → paste → Run

-- ─── sales ───────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "sales read" ON public.sales;

CREATE POLICY "sales read"
  ON public.sales FOR SELECT TO authenticated
  USING (
    store_id = public.current_user_store_id()
    AND (
      public.current_user_role() IN ('owner', 'manager')
      OR seller_id = auth.uid()
    )
  );

-- ─── sale_items ───────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "sale items read" ON public.sale_items;

CREATE POLICY "sale items read"
  ON public.sale_items FOR SELECT TO authenticated
  USING (
    store_id = public.current_user_store_id()
    AND (
      public.current_user_role() IN ('owner', 'manager')
      OR EXISTS (
        SELECT 1 FROM public.sales s
        WHERE s.id = sale_id AND s.seller_id = auth.uid()
      )
    )
  );

-- Phase 7: Inventory & Stock Movements
-- Changes:
--   1. adjust_stock() RPC — owner/manager stock correction with reason
-- categories and stock_movements tables already exist from 001_init.sql.
-- No new tables. No existing data touched.
--
-- How to run:
--   Supabase CLI:       supabase db push
--   Supabase Dashboard: SQL Editor -> paste this file -> Run

DROP FUNCTION IF EXISTS public.adjust_stock(uuid, numeric, text);

CREATE OR REPLACE FUNCTION public.adjust_stock(
  p_product_id      uuid,
  p_quantity_change numeric,   -- positive = add stock, negative = remove stock
  p_reason          text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_store_id  uuid := public.current_user_store_id();
  v_role      text := public.current_user_role();
  v_product   public.products%rowtype;
  v_new_stock numeric(12,2);
  v_type      text;
BEGIN
  IF v_store_id IS NULL THEN RAISE EXCEPTION 'User profile/store not found'; END IF;
  IF v_role NOT IN ('owner', 'manager') THEN RAISE EXCEPTION 'Only owners and managers can adjust stock'; END IF;
  IF p_quantity_change = 0 THEN RAISE EXCEPTION 'Quantity change cannot be zero'; END IF;
  IF p_reason IS NULL OR length(trim(p_reason)) < 3 THEN
    RAISE EXCEPTION 'Reason is required (minimum 3 characters)';
  END IF;

  SELECT * INTO v_product FROM public.products
    WHERE id = p_product_id AND store_id = v_store_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Product not found'; END IF;

  v_new_stock := v_product.current_stock + p_quantity_change;
  IF v_new_stock < 0 THEN RAISE EXCEPTION 'Adjustment would result in negative stock'; END IF;

  v_type := CASE WHEN p_quantity_change > 0 THEN 'adjustment_in' ELSE 'adjustment_out' END;

  INSERT INTO public.stock_movements(store_id, product_id, movement_type, quantity,
    previous_stock, new_stock, reference_id, created_by, approval_status, notes)
  VALUES (v_store_id, p_product_id, v_type, abs(p_quantity_change),
    v_product.current_stock, v_new_stock, NULL, auth.uid(), 'not_required', trim(p_reason));

  UPDATE public.products
    SET current_stock = v_new_stock, updated_at = now()
    WHERE id = p_product_id;
END;
$$;

-- Phase 4: Role-Based Access
-- Changes:
--   1. Products: managers can insert and update (not just owners)
--   2. Categories: managers can insert and update
--   3. Customers: managers can update (add was already open to all)
--   4. create_cash_sale RPC: allow manager role
--   5. request_credit_sale RPC: allow manager role
-- No table structure changes. No existing data touched.
--
-- How to run:
--   Supabase CLI:       supabase db push
--   Supabase Dashboard: SQL Editor -> paste this file -> Run

-- ─── 1. Products RLS ──────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "owner products insert" ON public.products;
DROP POLICY IF EXISTS "owner products update" ON public.products;

CREATE POLICY "owner manager products insert"
  ON public.products FOR INSERT TO authenticated
  WITH CHECK (
    store_id = public.current_user_store_id()
    AND public.current_user_role() IN ('owner', 'manager')
  );

CREATE POLICY "owner manager products update"
  ON public.products FOR UPDATE TO authenticated
  USING (
    store_id = public.current_user_store_id()
    AND public.current_user_role() IN ('owner', 'manager')
  );

-- ─── 2. Categories RLS ───────────────────────────────────────────────────────
DROP POLICY IF EXISTS "owner categories insert" ON public.categories;
DROP POLICY IF EXISTS "owner categories update" ON public.categories;

CREATE POLICY "owner manager categories insert"
  ON public.categories FOR INSERT TO authenticated
  WITH CHECK (
    store_id = public.current_user_store_id()
    AND public.current_user_role() IN ('owner', 'manager')
  );

CREATE POLICY "owner manager categories update"
  ON public.categories FOR UPDATE TO authenticated
  USING (
    store_id = public.current_user_store_id()
    AND public.current_user_role() IN ('owner', 'manager')
  );

-- ─── 3. Customers update RLS ─────────────────────────────────────────────────
DROP POLICY IF EXISTS "customers update owner" ON public.customers;

CREATE POLICY "owner manager customers update"
  ON public.customers FOR UPDATE TO authenticated
  USING (
    store_id = public.current_user_store_id()
    AND public.current_user_role() IN ('owner', 'manager')
  );

-- ─── 4. create_cash_sale RPC: allow manager ───────────────────────────────────
-- Only change from 001_init.sql: role check includes 'manager'.
CREATE OR REPLACE FUNCTION public.create_cash_sale(
  p_customer_id uuid,
  p_items jsonb,
  p_payment_method text,
  p_reference_no text DEFAULT NULL,
  p_discount numeric DEFAULT 0,
  p_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_store_id uuid := public.current_user_store_id();
  v_role     text := public.current_user_role();
  v_sale_id  uuid := gen_random_uuid();
  v_invoice  text := public.new_invoice_no();
  v_subtotal numeric(12,2) := 0;
  v_total    numeric(12,2) := 0;
  v_item     jsonb;
  v_product  public.products%rowtype;
  v_qty      numeric(12,2);
  v_line_total numeric(12,2);
BEGIN
  IF v_store_id IS NULL THEN RAISE EXCEPTION 'User profile/store not found'; END IF;
  IF v_role NOT IN ('owner', 'manager', 'seller') THEN RAISE EXCEPTION 'Not allowed'; END IF;
  IF p_payment_method NOT IN ('cash', 'bank', 'mobile_money', 'mixed') THEN RAISE EXCEPTION 'Invalid payment method'; END IF;
  IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN RAISE EXCEPTION 'Sale items are required'; END IF;
  IF coalesce(p_discount,0) < 0 THEN RAISE EXCEPTION 'Discount cannot be negative'; END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_qty := (v_item->>'quantity')::numeric;
    IF v_qty <= 0 THEN RAISE EXCEPTION 'Quantity must be positive'; END IF;
    SELECT * INTO v_product FROM public.products
      WHERE id = (v_item->>'product_id')::uuid AND store_id = v_store_id AND is_active = true FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Product not found'; END IF;
    IF v_product.current_stock < v_qty THEN RAISE EXCEPTION 'Insufficient stock for %', v_product.name; END IF;
    IF v_product.selling_price < v_product.minimum_selling_price THEN RAISE EXCEPTION 'Selling price below minimum for %', v_product.name; END IF;
    v_line_total := v_qty * v_product.selling_price;
    v_subtotal   := v_subtotal + v_line_total;
  END LOOP;

  v_total := v_subtotal - coalesce(p_discount,0);
  IF v_total < 0 THEN RAISE EXCEPTION 'Discount cannot exceed subtotal'; END IF;

  INSERT INTO public.sales(id, store_id, seller_id, customer_id, invoice_no, sale_type, subtotal, discount,
    total_amount, paid_amount, balance_amount, payment_status, approval_status, status, notes)
  VALUES (v_sale_id, v_store_id, auth.uid(), p_customer_id, v_invoice, 'cash',
    v_subtotal, coalesce(p_discount,0), v_total, v_total, 0, 'paid', 'not_required', 'completed', p_notes);

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_qty := (v_item->>'quantity')::numeric;
    SELECT * INTO v_product FROM public.products
      WHERE id = (v_item->>'product_id')::uuid AND store_id = v_store_id FOR UPDATE;
    v_line_total := v_qty * v_product.selling_price;
    INSERT INTO public.sale_items(store_id, sale_id, product_id, product_name, unit, quantity, unit_price, total_price)
    VALUES (v_store_id, v_sale_id, v_product.id, v_product.name, v_product.unit, v_qty, v_product.selling_price, v_line_total);
    INSERT INTO public.stock_movements(store_id, product_id, movement_type, quantity, previous_stock, new_stock,
      reference_id, created_by, approval_status, notes)
    VALUES (v_store_id, v_product.id, 'sale', v_qty, v_product.current_stock,
      v_product.current_stock - v_qty, v_sale_id, auth.uid(), 'not_required', 'Sale ' || v_invoice);
    UPDATE public.products SET current_stock = current_stock - v_qty, updated_at = now() WHERE id = v_product.id;
  END LOOP;

  INSERT INTO public.payments(store_id, sale_id, customer_id, seller_id, amount, payment_method, reference_no, notes)
  VALUES (v_store_id, v_sale_id, p_customer_id, auth.uid(), v_total, p_payment_method, p_reference_no, p_notes);

  PERFORM public.log_action('create_cash_sale', 'sales', v_sale_id, NULL,
    jsonb_build_object('invoice_no', v_invoice, 'total', v_total));
  RETURN v_sale_id;
END;
$$;

-- ─── 5. request_credit_sale RPC: allow manager ────────────────────────────────
-- Only change from 001_init.sql: role check includes 'manager'.
CREATE OR REPLACE FUNCTION public.request_credit_sale(
  p_customer_id uuid,
  p_items jsonb,
  p_reason text,
  p_discount numeric DEFAULT 0,
  p_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_store_id   uuid := public.current_user_store_id();
  v_role       text := public.current_user_role();
  v_sale_id    uuid := gen_random_uuid();
  v_request_id uuid := gen_random_uuid();
  v_invoice    text := public.new_invoice_no();
  v_subtotal   numeric(12,2) := 0;
  v_total      numeric(12,2) := 0;
  v_item       jsonb;
  v_product    public.products%rowtype;
  v_qty        numeric(12,2);
  v_line_total numeric(12,2);
BEGIN
  IF v_store_id IS NULL THEN RAISE EXCEPTION 'User profile/store not found'; END IF;
  IF v_role NOT IN ('owner', 'manager', 'seller') THEN RAISE EXCEPTION 'Not allowed'; END IF;
  IF p_customer_id IS NULL THEN RAISE EXCEPTION 'Credit sale requires customer'; END IF;
  IF p_reason IS NULL OR length(trim(p_reason)) < 3 THEN RAISE EXCEPTION 'Reason is required'; END IF;
  IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN RAISE EXCEPTION 'Sale items are required'; END IF;

  IF NOT EXISTS (SELECT 1 FROM public.customers WHERE id = p_customer_id AND store_id = v_store_id) THEN
    RAISE EXCEPTION 'Customer not found';
  END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_qty := (v_item->>'quantity')::numeric;
    IF v_qty <= 0 THEN RAISE EXCEPTION 'Quantity must be positive'; END IF;
    SELECT * INTO v_product FROM public.products
      WHERE id = (v_item->>'product_id')::uuid AND store_id = v_store_id AND is_active = true;
    IF NOT FOUND THEN RAISE EXCEPTION 'Product not found'; END IF;
    IF v_product.current_stock < v_qty THEN RAISE EXCEPTION 'Insufficient stock for %', v_product.name; END IF;
    v_line_total := v_qty * v_product.selling_price;
    v_subtotal   := v_subtotal + v_line_total;
  END LOOP;

  v_total := v_subtotal - coalesce(p_discount,0);
  IF v_total < 0 THEN RAISE EXCEPTION 'Discount cannot exceed subtotal'; END IF;

  INSERT INTO public.sales(id, store_id, seller_id, customer_id, invoice_no, sale_type, subtotal, discount,
    total_amount, paid_amount, balance_amount, payment_status, approval_status, status, notes)
  VALUES (v_sale_id, v_store_id, auth.uid(), p_customer_id, v_invoice, 'credit',
    v_subtotal, coalesce(p_discount,0), v_total, 0, v_total, 'unpaid', 'pending', 'draft', p_notes);

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_qty := (v_item->>'quantity')::numeric;
    SELECT * INTO v_product FROM public.products
      WHERE id = (v_item->>'product_id')::uuid AND store_id = v_store_id;
    v_line_total := v_qty * v_product.selling_price;
    INSERT INTO public.sale_items(store_id, sale_id, product_id, product_name, unit, quantity, unit_price, total_price)
    VALUES (v_store_id, v_sale_id, v_product.id, v_product.name, v_product.unit, v_qty, v_product.selling_price, v_line_total);
  END LOOP;

  INSERT INTO public.approval_requests(id, store_id, requested_by, request_type, reference_id, amount, reason)
  VALUES (v_request_id, v_store_id, auth.uid(), 'credit_sale', v_sale_id, v_total, p_reason);

  INSERT INTO public.notifications(store_id, user_id, title, message, type)
  SELECT v_store_id, id, 'Credit sale approval needed',
    'A credit sale of ETB ' || v_total || ' needs approval.', 'approval'
  FROM public.profiles WHERE store_id = v_store_id AND role = 'owner' AND is_active = true;

  PERFORM public.log_action('request_credit_sale', 'approval_requests', v_request_id, NULL,
    jsonb_build_object('sale_id', v_sale_id, 'total', v_total));
  RETURN v_request_id;
END;
$$;

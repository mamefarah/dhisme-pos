-- Phase 18: Profit Tracking & Payment Method on Sales
--
-- Changes:
--   A. Add sales.payment_method  — denormalised copy of the payment method so
--      the sales list and reports can filter without joining payments.
--   B. Add sale_items.buying_price_at_sale — snapshot of product cost at sale time.
--      Add sale_items.gross_profit          — (selling - buying) * qty, stored for fast reports.
--   C. Rewrite create_cash_sale() and request_credit_sale() to populate the new columns.
--   D. Backfill historical rows.
--
-- How to run:
--   Supabase CLI:       supabase db push
--   Supabase Dashboard: SQL Editor → paste → Run

-- ─── A. Schema additions ──────────────────────────────────────────────────────
ALTER TABLE public.sales
  ADD COLUMN IF NOT EXISTS payment_method text;

ALTER TABLE public.sale_items
  ADD COLUMN IF NOT EXISTS buying_price_at_sale numeric(12,2),
  ADD COLUMN IF NOT EXISTS gross_profit         numeric(12,2);

-- ─── B. Backfill existing rows ────────────────────────────────────────────────
-- Set sales.payment_method from the first payment recorded for each sale.
UPDATE public.sales s
SET payment_method = p.payment_method
FROM (
  SELECT DISTINCT ON (sale_id) sale_id, payment_method
  FROM public.payments
  ORDER BY sale_id, created_at
) p
WHERE s.id = p.sale_id
  AND s.payment_method IS NULL;

-- Set sale_items cost/profit snapshot using the product's current buying_price.
-- Historical accuracy is limited to today's cost; future sales will record the
-- correct snapshot at point of sale.
UPDATE public.sale_items si
SET
  buying_price_at_sale = p.buying_price,
  gross_profit         = round((si.unit_price - p.buying_price) * si.quantity, 2)
FROM public.products p
WHERE si.product_id = p.id
  AND si.buying_price_at_sale IS NULL;

-- ─── C. create_cash_sale — add payment_method + buying_price_at_sale ─────────
CREATE OR REPLACE FUNCTION public.create_cash_sale(
  p_customer_id    uuid,
  p_items          jsonb,
  p_payment_method text,
  p_reference_no   text    DEFAULT NULL,
  p_discount       numeric DEFAULT 0,
  p_notes          text    DEFAULT NULL
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
  v_invoice    text := public.new_invoice_no();
  v_subtotal   numeric(12,2) := 0;
  v_total      numeric(12,2) := 0;
  v_item       jsonb;
  v_product    public.products%ROWTYPE;
  v_qty        numeric(12,2);
  v_line_total numeric(12,2);
BEGIN
  IF v_store_id IS NULL THEN RAISE EXCEPTION 'User profile/store not found'; END IF;
  IF v_role NOT IN ('owner', 'manager', 'seller') THEN RAISE EXCEPTION 'Not allowed'; END IF;
  IF p_payment_method NOT IN ('cash', 'bank', 'mobile_money', 'mixed') THEN
    RAISE EXCEPTION 'Invalid payment method';
  END IF;
  IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'Sale items are required';
  END IF;
  IF coalesce(p_discount, 0) < 0 THEN RAISE EXCEPTION 'Discount cannot be negative'; END IF;

  -- Validate and calculate subtotal
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_qty := (v_item->>'quantity')::numeric;
    IF v_qty <= 0 THEN RAISE EXCEPTION 'Quantity must be positive'; END IF;

    SELECT * INTO v_product FROM public.products
    WHERE id = (v_item->>'product_id')::uuid
      AND store_id = v_store_id
      AND is_active = true
    FOR UPDATE;

    IF NOT FOUND THEN RAISE EXCEPTION 'Product not found'; END IF;
    IF v_product.current_stock < v_qty THEN
      RAISE EXCEPTION 'Insufficient stock for %', v_product.name;
    END IF;
    IF v_product.selling_price < v_product.minimum_selling_price THEN
      RAISE EXCEPTION 'Selling price below minimum for %', v_product.name;
    END IF;

    v_line_total := v_qty * v_product.selling_price;
    v_subtotal   := v_subtotal + v_line_total;
  END LOOP;

  v_total := v_subtotal - coalesce(p_discount, 0);
  IF v_total < 0 THEN RAISE EXCEPTION 'Discount cannot exceed subtotal'; END IF;

  INSERT INTO public.sales(
    id, store_id, seller_id, customer_id, invoice_no, sale_type,
    subtotal, discount, total_amount, paid_amount, balance_amount,
    payment_status, approval_status, status, notes, payment_method
  ) VALUES (
    v_sale_id, v_store_id, auth.uid(), p_customer_id, v_invoice, 'cash',
    v_subtotal, coalesce(p_discount, 0), v_total, v_total, 0,
    'paid', 'not_required', 'completed', p_notes, p_payment_method
  );

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_qty := (v_item->>'quantity')::numeric;
    SELECT * INTO v_product FROM public.products
    WHERE id = (v_item->>'product_id')::uuid AND store_id = v_store_id FOR UPDATE;
    v_line_total := v_qty * v_product.selling_price;

    INSERT INTO public.sale_items(
      store_id, sale_id, product_id, product_name, unit,
      quantity, unit_price, total_price,
      buying_price_at_sale, gross_profit
    ) VALUES (
      v_store_id, v_sale_id, v_product.id, v_product.name, v_product.unit,
      v_qty, v_product.selling_price, v_line_total,
      v_product.buying_price,
      round((v_product.selling_price - v_product.buying_price) * v_qty, 2)
    );

    INSERT INTO public.stock_movements(
      store_id, product_id, movement_type, quantity,
      previous_stock, new_stock, reference_id, created_by, approval_status, notes
    ) VALUES (
      v_store_id, v_product.id, 'sale', v_qty,
      v_product.current_stock, v_product.current_stock - v_qty,
      v_sale_id, auth.uid(), 'not_required', 'Sale ' || v_invoice
    );

    UPDATE public.products
    SET current_stock = current_stock - v_qty, updated_at = now()
    WHERE id = v_product.id;
  END LOOP;

  INSERT INTO public.payments(
    store_id, sale_id, customer_id, seller_id, amount, payment_method, reference_no, notes
  ) VALUES (
    v_store_id, v_sale_id, p_customer_id, auth.uid(), v_total, p_payment_method, p_reference_no, p_notes
  );

  PERFORM public.log_action('create_cash_sale', 'sales', v_sale_id, NULL,
    jsonb_build_object('invoice_no', v_invoice, 'total', v_total, 'payment_method', p_payment_method));
  RETURN v_sale_id;
END;
$$;

-- ─── D. request_credit_sale — add buying_price_at_sale ────────────────────────
CREATE OR REPLACE FUNCTION public.request_credit_sale(
  p_customer_id uuid,
  p_items       jsonb,
  p_reason      text,
  p_discount    numeric DEFAULT 0,
  p_notes       text    DEFAULT NULL
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
  v_product    public.products%ROWTYPE;
  v_qty        numeric(12,2);
  v_line_total numeric(12,2);
BEGIN
  IF v_store_id IS NULL THEN RAISE EXCEPTION 'User profile/store not found'; END IF;
  IF v_role NOT IN ('owner', 'manager', 'seller') THEN RAISE EXCEPTION 'Not allowed'; END IF;
  IF p_customer_id IS NULL THEN RAISE EXCEPTION 'Credit sale requires customer'; END IF;
  IF p_reason IS NULL OR length(trim(p_reason)) < 3 THEN RAISE EXCEPTION 'Reason is required'; END IF;
  IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'Sale items are required';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.customers WHERE id = p_customer_id AND store_id = v_store_id
  ) THEN
    RAISE EXCEPTION 'Customer not found';
  END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_qty := (v_item->>'quantity')::numeric;
    IF v_qty <= 0 THEN RAISE EXCEPTION 'Quantity must be positive'; END IF;
    SELECT * INTO v_product FROM public.products
    WHERE id = (v_item->>'product_id')::uuid AND store_id = v_store_id AND is_active = true;
    IF NOT FOUND THEN RAISE EXCEPTION 'Product not found'; END IF;
    IF v_product.current_stock < v_qty THEN
      RAISE EXCEPTION 'Insufficient stock for %', v_product.name;
    END IF;
    v_line_total := v_qty * v_product.selling_price;
    v_subtotal   := v_subtotal + v_line_total;
  END LOOP;

  v_total := v_subtotal - coalesce(p_discount, 0);
  IF v_total < 0 THEN RAISE EXCEPTION 'Discount cannot exceed subtotal'; END IF;

  INSERT INTO public.sales(
    id, store_id, seller_id, customer_id, invoice_no, sale_type,
    subtotal, discount, total_amount, paid_amount, balance_amount,
    payment_status, approval_status, status, notes
  ) VALUES (
    v_sale_id, v_store_id, auth.uid(), p_customer_id, v_invoice, 'credit',
    v_subtotal, coalesce(p_discount, 0), v_total, 0, v_total,
    'unpaid', 'pending', 'draft', p_notes
  );

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_qty := (v_item->>'quantity')::numeric;
    SELECT * INTO v_product FROM public.products
    WHERE id = (v_item->>'product_id')::uuid AND store_id = v_store_id;
    v_line_total := v_qty * v_product.selling_price;

    INSERT INTO public.sale_items(
      store_id, sale_id, product_id, product_name, unit,
      quantity, unit_price, total_price,
      buying_price_at_sale, gross_profit
    ) VALUES (
      v_store_id, v_sale_id, v_product.id, v_product.name, v_product.unit,
      v_qty, v_product.selling_price, v_line_total,
      v_product.buying_price,
      round((v_product.selling_price - v_product.buying_price) * v_qty, 2)
    );
  END LOOP;

  INSERT INTO public.approval_requests(id, store_id, requested_by, request_type, reference_id, amount, reason)
  VALUES (v_request_id, v_store_id, auth.uid(), 'credit_sale', v_sale_id, v_total, p_reason);

  INSERT INTO public.notifications(store_id, user_id, title, message, type)
  SELECT v_store_id, id,
    'Credit sale approval needed',
    'A credit sale of ETB ' || v_total || ' needs approval.',
    'approval'
  FROM public.profiles
  WHERE store_id = v_store_id AND role = 'owner' AND is_active = true;

  PERFORM public.log_action('request_credit_sale', 'approval_requests', v_request_id, NULL,
    jsonb_build_object('sale_id', v_sale_id, 'total', v_total));
  RETURN v_request_id;
END;
$$;

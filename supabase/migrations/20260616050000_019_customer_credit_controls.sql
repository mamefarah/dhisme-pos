-- Phase 19: Customer Credit Controls
--
-- Changes:
--   A. Add credit_limit, credit_days, credit_blocked columns to customers.
--   B. Rewrite request_credit_sale() to enforce credit limits and blocked status.
--
-- credit_limit = 0 means no limit is enforced.
-- credit_days  = 0 means no time restriction (shown in UI only; not enforced server-side).
-- credit_blocked = true prevents any new credit sales for that customer.
--
-- How to run:
--   Supabase CLI:       supabase db push
--   Supabase Dashboard: SQL Editor → paste → Run

-- ─── A. Extend customers ──────────────────────────────────────────────────────
ALTER TABLE public.customers
  ADD COLUMN IF NOT EXISTS credit_limit   numeric(12,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS credit_days    int           NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS credit_blocked boolean       NOT NULL DEFAULT false;

-- ─── B. request_credit_sale — enforce credit controls ─────────────────────────
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
  v_customer   public.customers%ROWTYPE;
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

  SELECT * INTO v_customer
  FROM public.customers
  WHERE id = p_customer_id AND store_id = v_store_id;

  IF NOT FOUND THEN RAISE EXCEPTION 'Customer not found'; END IF;

  IF v_customer.credit_blocked THEN
    RAISE EXCEPTION 'This customer is blocked from credit sales. Please contact the store owner.';
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

  IF v_customer.credit_limit > 0
     AND (v_customer.total_balance + v_total) > v_customer.credit_limit THEN
    RAISE EXCEPTION 'Credit limit exceeded. Current balance: ETB %. Limit: ETB %.',
      v_customer.total_balance, v_customer.credit_limit;
  END IF;

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

-- Phase 6: Purchases / Stock-In
-- New tables: purchases, purchase_items
-- New RPC: record_purchase (atomic — stock update + movement in one transaction)
-- No existing tables or data modified.
--
-- How to run:
--   Supabase CLI:       supabase db push
--   Supabase Dashboard: SQL Editor -> paste this file -> Run

-- ─── 1. purchases ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.purchases (
  id             uuid          PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id       uuid          NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  supplier_id    uuid          REFERENCES public.suppliers(id),
  invoice_ref    text,
  purchase_date  date          NOT NULL DEFAULT current_date,
  payment_status text          NOT NULL DEFAULT 'paid'
                               CHECK (payment_status IN ('paid', 'partial', 'unpaid')),
  total_amount   numeric(12,2) NOT NULL DEFAULT 0,
  notes          text,
  recorded_by    uuid          REFERENCES public.profiles(id),
  created_at     timestamptz   NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_purchases_store
  ON public.purchases(store_id, purchase_date DESC);

-- ─── 2. purchase_items ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.purchase_items (
  id           uuid          PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id     uuid          NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  purchase_id  uuid          NOT NULL REFERENCES public.purchases(id) ON DELETE CASCADE,
  product_id   uuid          NOT NULL REFERENCES public.products(id),
  product_name text          NOT NULL,
  unit         text          NOT NULL,
  quantity     numeric(12,2) NOT NULL CHECK (quantity > 0),
  unit_cost    numeric(12,2) NOT NULL CHECK (unit_cost >= 0),
  total_cost   numeric(12,2) NOT NULL
);

-- ─── 3. RLS ───────────────────────────────────────────────────────────────────
ALTER TABLE public.purchases      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.purchase_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "purchases select store"      ON public.purchases;
DROP POLICY IF EXISTS "purchase_items select store" ON public.purchase_items;

CREATE POLICY "purchases select store"
  ON public.purchases FOR SELECT TO authenticated
  USING (store_id = public.current_user_store_id());

CREATE POLICY "purchase_items select store"
  ON public.purchase_items FOR SELECT TO authenticated
  USING (store_id = public.current_user_store_id());

-- ─── 4. RPC: record_purchase ──────────────────────────────────────────────────
-- p_items: [{"product_id": "uuid", "quantity": 10, "unit_cost": 25.50}, ...]
CREATE OR REPLACE FUNCTION public.record_purchase(
  p_items          jsonb,
  p_supplier_id    uuid    DEFAULT NULL,
  p_invoice_ref    text    DEFAULT NULL,
  p_purchase_date  date    DEFAULT current_date,
  p_payment_status text    DEFAULT 'paid',
  p_notes          text    DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_store_id    uuid := public.current_user_store_id();
  v_role        text := public.current_user_role();
  v_purchase_id uuid := gen_random_uuid();
  v_total       numeric(12,2) := 0;
  v_item        jsonb;
  v_product     public.products%rowtype;
  v_qty         numeric(12,2);
  v_cost        numeric(12,2);
  v_line_total  numeric(12,2);
BEGIN
  IF v_store_id IS NULL THEN RAISE EXCEPTION 'User profile/store not found'; END IF;
  IF v_role NOT IN ('owner', 'manager') THEN RAISE EXCEPTION 'Only owners and managers can record purchases'; END IF;
  IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN RAISE EXCEPTION 'Purchase items are required'; END IF;
  IF p_payment_status NOT IN ('paid', 'partial', 'unpaid') THEN RAISE EXCEPTION 'Invalid payment status'; END IF;

  -- Validate all items before writing anything.
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_qty  := (v_item->>'quantity')::numeric;
    v_cost := (v_item->>'unit_cost')::numeric;
    IF v_qty  <= 0 THEN RAISE EXCEPTION 'Quantity must be positive'; END IF;
    IF v_cost <  0 THEN RAISE EXCEPTION 'Unit cost cannot be negative'; END IF;
    SELECT * INTO v_product FROM public.products
      WHERE id = (v_item->>'product_id')::uuid AND store_id = v_store_id AND is_active = true;
    IF NOT FOUND THEN RAISE EXCEPTION 'Product not found or inactive'; END IF;
    v_total := v_total + (v_qty * v_cost);
  END LOOP;

  -- Insert purchase header.
  INSERT INTO public.purchases(id, store_id, supplier_id, invoice_ref, purchase_date,
    payment_status, total_amount, notes, recorded_by)
  VALUES (v_purchase_id, v_store_id, p_supplier_id,
    nullif(trim(coalesce(p_invoice_ref, '')), ''),
    p_purchase_date, p_payment_status, v_total, p_notes, auth.uid());

  -- Insert items, increment stock, record movements.
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_qty  := (v_item->>'quantity')::numeric;
    v_cost := (v_item->>'unit_cost')::numeric;
    SELECT * INTO v_product FROM public.products
      WHERE id = (v_item->>'product_id')::uuid AND store_id = v_store_id FOR UPDATE;
    v_line_total := v_qty * v_cost;

    INSERT INTO public.purchase_items(store_id, purchase_id, product_id, product_name, unit,
      quantity, unit_cost, total_cost)
    VALUES (v_store_id, v_purchase_id, v_product.id, v_product.name, v_product.unit,
      v_qty, v_cost, v_line_total);

    INSERT INTO public.stock_movements(store_id, product_id, movement_type, quantity,
      previous_stock, new_stock, reference_id, created_by, approval_status, notes)
    VALUES (v_store_id, v_product.id, 'purchase', v_qty, v_product.current_stock,
      v_product.current_stock + v_qty, v_purchase_id, auth.uid(), 'not_required',
      'Purchase' || coalesce(' ' || nullif(trim(coalesce(p_invoice_ref, '')), ''), ''));

    UPDATE public.products
      SET current_stock = current_stock + v_qty,
          buying_price  = v_cost,
          updated_at    = now()
      WHERE id = v_product.id;
  END LOOP;

  PERFORM public.log_action('record_purchase', 'purchases', v_purchase_id, NULL,
    jsonb_build_object('total', v_total, 'items', jsonb_array_length(p_items)));
  RETURN v_purchase_id;
END;
$$;

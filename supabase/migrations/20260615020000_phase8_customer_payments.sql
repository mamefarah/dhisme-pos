-- Phase 8: Customer Debt Management
-- Changes:
--   1. Add notes, is_active columns to customers
--   2. New customer_payments table with RLS
--   3. record_customer_payment() RPC
-- No existing customer data is modified.
--
-- How to run:
--   Supabase CLI:       supabase db push
--   Supabase Dashboard: SQL Editor -> paste this file -> Run

-- ─── 1. Extend customers ──────────────────────────────────────────────────────
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS notes     text;
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS is_active boolean NOT NULL DEFAULT true;

-- ─── 2. customer_payments ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.customer_payments (
  id             uuid          PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id       uuid          NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  customer_id    uuid          NOT NULL REFERENCES public.customers(id),
  received_by    uuid          REFERENCES public.profiles(id),
  amount         numeric(12,2) NOT NULL CHECK (amount > 0),
  payment_method text          NOT NULL CHECK (payment_method IN ('cash', 'bank', 'mobile_money')),
  reference_no   text,
  notes          text,
  created_at     timestamptz   NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_customer_payments_customer
  ON public.customer_payments(customer_id, created_at DESC);

ALTER TABLE public.customer_payments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "customer_payments select store" ON public.customer_payments;
CREATE POLICY "customer_payments select store"
  ON public.customer_payments FOR SELECT TO authenticated
  USING (store_id = public.current_user_store_id());

-- ─── 3. RPC: record_customer_payment ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.record_customer_payment(
  p_customer_id    uuid,
  p_amount         numeric,
  p_payment_method text,
  p_reference_no   text    DEFAULT NULL,
  p_notes          text    DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_store_id   uuid := public.current_user_store_id();
  v_payment_id uuid := gen_random_uuid();
  v_customer   public.customers%rowtype;
BEGIN
  IF v_store_id IS NULL THEN RAISE EXCEPTION 'User profile/store not found'; END IF;
  IF p_amount <= 0 THEN RAISE EXCEPTION 'Payment amount must be greater than zero'; END IF;
  IF p_payment_method NOT IN ('cash', 'bank', 'mobile_money') THEN
    RAISE EXCEPTION 'Invalid payment method';
  END IF;

  SELECT * INTO v_customer FROM public.customers
    WHERE id = p_customer_id AND store_id = v_store_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Customer not found'; END IF;
  IF p_amount > v_customer.total_balance THEN
    RAISE EXCEPTION 'Payment (%) exceeds outstanding balance (%)', p_amount, v_customer.total_balance;
  END IF;

  INSERT INTO public.customer_payments(id, store_id, customer_id, received_by,
    amount, payment_method, reference_no, notes)
  VALUES (v_payment_id, v_store_id, p_customer_id, auth.uid(),
    p_amount, p_payment_method,
    nullif(trim(coalesce(p_reference_no, '')), ''),
    nullif(trim(coalesce(p_notes, '')), ''));

  UPDATE public.customers
    SET total_balance = total_balance - p_amount
    WHERE id = p_customer_id;

  PERFORM public.log_action('record_customer_payment', 'customer_payments', v_payment_id, NULL,
    jsonb_build_object('customer_id', p_customer_id, 'amount', p_amount));
  RETURN v_payment_id;
END;
$$;

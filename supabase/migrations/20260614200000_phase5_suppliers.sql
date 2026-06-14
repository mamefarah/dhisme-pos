-- Phase 5: Suppliers
-- Adds a suppliers table scoped to each store.
-- No existing tables or data are modified.
--
-- How to run:
--   Supabase CLI:       supabase db push
--   Supabase Dashboard: SQL Editor -> paste this file -> Run

CREATE TABLE IF NOT EXISTS public.suppliers (
  id             uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id       uuid        NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  name           text        NOT NULL CHECK (length(trim(name)) >= 2),
  phone          text,
  address        text,
  contact_person text,
  notes          text,
  is_active      boolean     NOT NULL DEFAULT true,
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_suppliers_store
  ON public.suppliers(store_id, is_active);

ALTER TABLE public.suppliers ENABLE ROW LEVEL SECURITY;

-- All store members can view suppliers (needed for purchase forms in Phase 6).
DROP POLICY IF EXISTS "suppliers select store" ON public.suppliers;
CREATE POLICY "suppliers select store"
  ON public.suppliers FOR SELECT TO authenticated
  USING (store_id = public.current_user_store_id());

-- Only owner/manager can add or edit suppliers.
DROP POLICY IF EXISTS "owner manager suppliers insert" ON public.suppliers;
CREATE POLICY "owner manager suppliers insert"
  ON public.suppliers FOR INSERT TO authenticated
  WITH CHECK (
    store_id = public.current_user_store_id()
    AND public.current_user_role() IN ('owner', 'manager')
  );

DROP POLICY IF EXISTS "owner manager suppliers update" ON public.suppliers;
CREATE POLICY "owner manager suppliers update"
  ON public.suppliers FOR UPDATE TO authenticated
  USING (
    store_id = public.current_user_store_id()
    AND public.current_user_role() IN ('owner', 'manager')
  );

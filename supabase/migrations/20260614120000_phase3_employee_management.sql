-- Phase 3: Employee management
-- Changes:
--   1. Adds 'manager' to the profiles.role constraint
--   2. Adds store_invites table with RLS
--   3. Adds create_store_invite() RPC (owner creates invite code)
--   4. Adds register_with_invite() RPC (employee joins store)
-- No existing data is modified.
--
-- How to run:
--   Supabase CLI:       supabase db push
--   Supabase Dashboard: SQL Editor -> paste this file -> Run

-- ─── 1. Add 'manager' to role constraint ─────────────────────────────────────
-- Safe: existing 'owner' and 'seller' rows still satisfy the new constraint.
ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_role_check;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_role_check
  CHECK (role IN ('owner', 'manager', 'seller'));

-- ─── 2. store_invites table ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.store_invites (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id    uuid        NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  code        text        NOT NULL UNIQUE,
  role        text        NOT NULL CHECK (role IN ('manager', 'seller')),
  created_by  uuid        NOT NULL REFERENCES public.profiles(id),
  expires_at  timestamptz NOT NULL DEFAULT now() + INTERVAL '7 days',
  used_at     timestamptz,
  used_by     uuid        REFERENCES public.profiles(id),
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_store_invites_store
  ON public.store_invites(store_id, used_at, expires_at DESC);

-- ─── 3. RLS for store_invites ─────────────────────────────────────────────────
ALTER TABLE public.store_invites ENABLE ROW LEVEL SECURITY;

-- Only the store owner can list invite codes.
CREATE POLICY "invites read owner"
  ON public.store_invites FOR SELECT TO authenticated
  USING (store_id = public.current_user_store_id()
     AND public.current_user_role() = 'owner');

-- ─── 4. RPC: owner creates a single-use invite code ──────────────────────────
CREATE OR REPLACE FUNCTION public.create_store_invite(p_role text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_store_id uuid := public.current_user_store_id();
  v_role     text := public.current_user_role();
  v_code     text;
BEGIN
  IF v_store_id IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF v_role <> 'owner' THEN RAISE EXCEPTION 'Only owners can create invite codes'; END IF;
  IF p_role NOT IN ('manager', 'seller') THEN
    RAISE EXCEPTION 'Role must be manager or seller';
  END IF;

  -- Generate a unique 8-character alphanumeric code; retry on the rare collision.
  LOOP
    v_code := upper(substring(replace(gen_random_uuid()::text, '-', ''), 1, 8));
    EXIT WHEN NOT EXISTS (
      SELECT 1 FROM public.store_invites
      WHERE code = v_code AND used_at IS NULL AND expires_at > now()
    );
  END LOOP;

  INSERT INTO public.store_invites(store_id, code, role, created_by)
  VALUES (v_store_id, v_code, p_role, auth.uid());

  RETURN v_code;
END;
$$;

-- ─── 5. RPC: employee registers using an invite code ─────────────────────────
CREATE OR REPLACE FUNCTION public.register_with_invite(
  p_full_name   text,
  p_invite_code text,
  p_phone       text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_invite public.store_invites%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;

  IF EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid()) THEN
    RAISE EXCEPTION 'An account profile already exists for this login.';
  END IF;

  IF p_full_name IS NULL OR length(trim(p_full_name)) < 2 THEN
    RAISE EXCEPTION 'Full name must be at least 2 characters';
  END IF;

  IF p_invite_code IS NULL OR length(trim(p_invite_code)) = 0 THEN
    RAISE EXCEPTION 'Invite code is required';
  END IF;

  -- Lock the row so two concurrent sign-ups cannot consume the same code.
  SELECT * INTO v_invite
  FROM public.store_invites
  WHERE code = upper(trim(p_invite_code))
    AND used_at IS NULL
    AND expires_at > now()
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invite code is invalid or has expired. Ask the store owner for a new one.';
  END IF;

  INSERT INTO public.profiles(id, store_id, full_name, phone, role, is_active)
  VALUES (
    auth.uid(),
    v_invite.store_id,
    trim(p_full_name),
    nullif(trim(coalesce(p_phone, '')), ''),
    v_invite.role,
    true
  );

  -- Single-use: mark invite as consumed.
  UPDATE public.store_invites
  SET used_at = now(), used_by = auth.uid()
  WHERE id = v_invite.id;
END;
$$;

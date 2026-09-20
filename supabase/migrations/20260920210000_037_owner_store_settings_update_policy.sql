-- public.stores has RLS enabled but, until now, only a SELECT policy
-- ("read own store"). An UPDATE from any authenticated user — owner or
-- manager — therefore matched zero rows under RLS instead of raising an
-- error: StoreSettingsScreen's "Save" showed a success message while the
-- store name/phone/address on printed receipts silently never changed.
--
-- This adds the missing UPDATE policy, scoped to the caller's own store and
-- restricted to the owner role, matching the product's intended model:
-- store identity (name/phone/address) is an owner-only change. Managers and
-- sellers continue to get zero rows (now paired with a client-side check —
-- see StoreRepository.updateStore — that treats zero rows as a failure
-- instead of a silent success).
--
-- No existing policy is touched and no store rows are modified by this
-- migration.
--
-- How to run:
--   Supabase CLI:       supabase db push
--   Supabase Dashboard: SQL Editor -> paste this file -> Run

drop policy if exists "owner store update" on public.stores;

create policy "owner store update"
on public.stores
for update
to authenticated
using (
  id = (select public.current_user_store_id())
  and (select public.current_user_role()) = 'owner'
)
with check (
  id = (select public.current_user_store_id())
  and (select public.current_user_role()) = 'owner'
);

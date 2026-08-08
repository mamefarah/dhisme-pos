# Dhisme POS — Controlled Pilot Release Checklist

Run this checklist before handing a validation APK to a pilot store. A green Flutter build alone is **not** a production release approval.

## Verified technical baseline — 08 Aug 2026

The following repository/database gates have been completed and independently rechecked:

- [x] Full committed Supabase migration chain through migration 029 reconstructs successfully on an isolated local Supabase/Postgres environment.
- [x] Automated database security/RLS suite passes **30/30** tests.
- [x] Aggregate `customers.total_balance` / `suppliers.total_balance` direct client writes are blocked while trusted transaction RPCs retain server-side maintenance capability.
- [x] Live rollback-safe Owner/Seller/cross-store verification passed after deployment of the balance hardening.
- [x] Flutter analyzer passes with `--fatal-infos`.
- [x] Automated Flutter tests pass.
- [x] Android release-mode validation APK compilation passes.

The remaining unchecked items are operational/pilot/production gates, not hidden code-completion claims.

---

## 1. Database reconstruction and migrations

Use the committed migration history as the source of truth. Do **not** apply only `001_init.sql` or stop at the older Phase migrations.

- [x] Reconstruct a fresh isolated Supabase/Postgres database from the repository migrations.
- [x] Apply **every file in `supabase/migrations/` in filename order** through migration 029.
- [x] Confirm migration execution completes without skipped/manual SQL.
- [x] Run automated customer/supplier, role, tenant, balance-tampering, and trusted-RPC database tests.
- [x] Verify authenticated clients cannot directly INSERT or UPDATE `customers.total_balance` or `suppliers.total_balance`.
- [x] Verify approved SECURITY DEFINER transaction RPCs can still maintain those balances.
- [x] Deploy the validated aggregate-balance hardening to the connected live Supabase project.
- [x] Verify the live deployment using rollback-safe authenticated Owner/Seller tests with no verification records left behind.

## 2. Supabase project security

- [x] `SUPABASE_URL` and the publishable/anon client key are supplied through build-time configuration; no service-role credential is embedded in Flutter source.
- [x] No `service_role` key is used by the Flutter application or validation build pipeline.
- [x] RLS/tenant behavior for the customer/supplier hardening is covered by automated database tests.
- [x] Supabase security advisor reviewed after deployment.
- [ ] Enable leaked-password protection before unrestricted production use. **Current advisor status: disabled.**
- [ ] Confirm Authentication email/redirect settings match the intended pilot onboarding flow.
- [ ] Maintain an explicit reviewed allowlist of authenticated SECURITY DEFINER RPCs. These RPCs are intentionally used as the server-side transaction boundary; do not blindly revoke them based only on the generic advisor warning.

## 3. GitHub validation

For every release candidate:

- [x] **Validate Dukaan Dhisme POS** is green for the current remediation.
- [x] `flutter analyze --fatal-infos` reports `No issues found`.
- [x] Automated Flutter tests pass.
- [x] **Validate Supabase Database** rebuilds the migration chain and passes 30/30 database tests.
- [x] **Build Dukaan Dhisme POS Validation APK** compiles successfully.
- [x] Validation jobs no longer depend on artifact upload, avoiding the previous artifact-quota failure mode.

The normal PR/push workflow verifies compilation but does not retain an APK. To obtain an installable validation APK, manually run **Build Dukaan Dhisme POS Validation APK** with `workflow_dispatch`.

- [ ] Manual APK workflow run succeeds after GitHub artifact storage is available.
- [ ] Artifact `dukaan-dhisme-pos-unsigned-validation-apk` is available.
- [ ] `BUILD_CHANNEL.txt` confirms it is an unsigned validation build.
- [ ] APK installs on the actual Android phones intended for the pilot.
- [ ] App opens, signs in, resumes, and relaunches without crashing.

## 4. Owner and employee onboarding

- [ ] Owner registration creates the correct store and owner profile on the pilot environment.
- [ ] `current_user_store_id()` resolves the correct store UUID.
- [ ] Owner creates seller and manager invite codes.
- [ ] Seller/manager joins the correct store and receives the correct role.
- [ ] Deactivated users cannot continue protected business operations.

## 5. Financial and operational pilot test

Run all scenarios in `docs/PILOT_TEST_SCRIPT.md`. At minimum verify on real pilot accounts/devices:

- [ ] Products/categories: create, edit, prices, minimum price, stock threshold.
- [ ] Stock adjustment: add/remove stock and verify movement history.
- [ ] Supplier: create/edit supplier and record purchases.
- [ ] Purchase: paid, unpaid, and partial payment flows; supplier balance reconciles.
- [ ] Cash/bank/mobile sale completes and stock decreases once.
- [ ] Mixed payment split exactly reconciles to sale total.
- [ ] Credit request enforces customer credit controls and approval rules.
- [ ] Customer payment allocates correctly and customer debt reconciles.
- [ ] Supplier payment allocates correctly and supplier debt reconciles.
- [ ] Full and partial returns restore stock and reconcile exact cumulative refunds.
- [ ] Expenses appear in the financial ledger and reports.
- [ ] Seller/manager daily cash closing matches the net ledger.
- [ ] Sales, returns, COGS, gross profit, expenses, and net profit reconcile to a manual sample.
- [ ] Retry/double-tap tests do not create duplicate sales, payments, purchases, expenses, or returns.

## 6. Role and tenant security spot-check

Automated database coverage now exercises these controls, but repeat the user-visible flows during the real pilot:

- [x] Automated tests verify Store A cannot read/mutate Store B customer data.
- [x] Automated tests verify seller cannot mutate owner/manager-only supplier/customer fields.
- [x] Automated tests verify direct aggregate customer/supplier balance tampering fails.
- [x] Automated tests verify trusted purchase RPC still updates server-owned supplier balance.
- [ ] Confirm equivalent restrictions through the installed app with two real pilot stores/accounts.
- [ ] Confirm unauthenticated API calls cannot execute privileged business RPCs as part of release security regression testing.

## 7. Backup, recovery, and observability

Required before unrestricted production rollout:

- [ ] Database backup policy is configured and documented.
- [ ] A restore drill has been completed against a non-production project/database.
- [ ] Flutter crash/error monitoring is configured.
- [ ] Operational alerts exist for material backend failures.
- [ ] A support/escalation process exists for reconciliation or data-integrity incidents.

## 8. Production Android release gate

The current GitHub APK is an **unsigned validation build**. Do not distribute it as the final production release.

Before production:

- [ ] Commit/stabilize the intended Android native project configuration rather than relying on generated validation-only Android files.
- [ ] Configure protected Android signing credentials/secrets.
- [ ] Produce and verify a signed release APK/AAB.
- [ ] Increment app version/build number for every production candidate.
- [ ] Verify package/application ID, target/compile SDK, permissions, backup settings, and release shrink/obfuscation policy.
- [ ] Test upgrade from the pilot build to the signed production build without data/session surprises.

## 9. Pilot limitations to communicate

- Offline mode is not implemented; core operation requires internet connectivity.
- PDF receipts/statements depend on compatible Android sharing/printing apps.
- Notifications are currently in-app rather than a complete push-notification/alerting system.
- Profit reporting depends on accurate buying-price data.
- Controlled-pilot technical gates are green, but unrestricted production remains blocked by the unchecked authentication, real-device pilot, backup/restore, monitoring, and signed-release requirements above.

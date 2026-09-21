# Dhisme POS — Controlled Pilot Release Checklist

Run this checklist before handing a validation APK to a pilot store. A green Flutter build alone is **not** a production release approval.

## Verified technical baseline — 08 Aug 2026

The following repository/database gates have been completed and independently rechecked:

- [x] Full committed Supabase migration chain through migration 032 reconstructs successfully on an isolated local Supabase/Postgres environment.
- [x] Automated database security/RLS suite passes **30/30** tests before and after an encrypted clean restore.
- [x] Aggregate `customers.total_balance` / `suppliers.total_balance` direct client writes are blocked while trusted transaction RPCs retain server-side maintenance capability.
- [x] Live rollback-safe Owner/Seller/cross-store verification passed after deployment of the balance hardening.
- [x] Recovery validation captured previously hidden production schema drift for return numbering, expense timestamps and cash-adjustment timestamps in migrations 030–032.
- [x] Encrypted logical backup → clean target → exact transactional-manifest restore passed; measured technical restore duration was **37 seconds** in CI.
- [x] Migrations 030–032 were deployed to the connected live Supabase project and verified with rollback-safe return, expense and cash-adjustment smoke transactions.
- [x] Flutter analyzer passes with `--fatal-infos`.
- [x] Automated Flutter tests pass.
- [x] Android release-mode validation compilation passes.
- [x] Android native project and Gradle wrapper are committed instead of generated ad hoc by each release build.
- [x] Validation and production signing paths are explicitly separated in Gradle/CI.

The remaining unchecked items are operational/pilot/account-configuration gates, not hidden code-completion claims.

## Security/build close-out — 21 Sep 2026

- [x] Migrations through **038** are live on the connected Supabase project and the project is `ACTIVE_HEALTHY`.
- [x] Android client-build workflows reject `sb_secret_` and non-`anon` legacy JWT credentials before compilation.
- [x] Validation workflow **#197, attempt 2** passed on commit `8e2f53191703085027e64f4cc2d08ac066c95afc`.
- [x] The retained validation artifact was inspected: its APK checksum matched `SHA256SUMS`, no full `sb_secret_` credential was present, and the embedded Supabase client credential matched the active publishable-key class.
- [x] Previously exposed validation artifacts identified during the incident response were removed.
- [x] Leaked-password protection is recorded as an **accepted Free-plan limitation** for the controlled pilot. Revisit it if the Supabase organization moves to Pro or above.
- [x] Permanent production `Test Manager - Dhisme` onboarding is **deferred by operator decision**. No fake production transactions were created; the existing manager invite remains unused until it expires or is replaced.

---

## 1. Database reconstruction and migrations

Use the committed migration history as the source of truth. Do **not** apply only `001_init.sql` or stop at the older Phase migrations.

- [x] Reconstruct a fresh isolated Supabase/Postgres database from the repository migrations.
- [x] Apply **every file in `supabase/migrations/` in filename order** through migration 032.
- [x] Confirm migration execution completes without skipped/manual SQL.
- [x] Run automated customer/supplier, role, tenant, balance-tampering, and trusted-RPC database tests.
- [x] Exercise purchase, cash sale, return, credit approval/payment, expense, cash adjustment, and daily closing in a persistent recovery fixture.
- [x] Verify authenticated clients cannot directly INSERT or UPDATE `customers.total_balance` or `suppliers.total_balance`.
- [x] Verify approved SECURITY DEFINER transaction RPCs can still maintain financial state.
- [x] Verify `new_return_no()` is available to trusted return logic but not directly executable by API client roles.
- [x] Deploy and verify the aggregate-balance hardening on the connected live Supabase project.
- [x] Deploy migration-history alignment 030–032 to the connected live project.
- [x] Live rollback-safe smoke test confirms return number generation, expense ledger writes and cash-adjustment ledger writes succeed; rollback leaves zero smoke rows and unchanged stock.

## 2. Supabase project security

- [x] `SUPABASE_URL` and the publishable/anon client key are supplied through build-time configuration; no service-role credential is embedded in Flutter source.
- [x] No `service_role` key is used by the Flutter application or validation build pipeline.
- [x] RLS/tenant behavior for the customer/supplier hardening is covered by automated database tests.
- [x] Supabase security advisor reviewed after deployment of migrations 030–032; no new RLS/financial-balance regression was reported.
- [x] Internal `new_return_no()` has no direct EXECUTE privilege for `anon` or `authenticated`.
- [x] Account creation has an app-side compensating password policy: 12+ characters including uppercase, lowercase, number, and symbol.
- [ ] Configure the Supabase Auth server-side minimum password length and required character classes to match the app policy.
- [ ] Enable leaked-password protection when the Supabase plan supports it. **Accepted limitation for the current controlled pilot on the Free plan; revisit after upgrading to Pro or above.**
- [ ] Confirm Authentication email/redirect settings match the intended pilot onboarding flow.
- [ ] Maintain an explicit reviewed allowlist of authenticated SECURITY DEFINER RPCs. These RPCs are intentionally used as the server-side transaction boundary; do not blindly revoke them based only on the generic advisor warning.

The app-side password rule is defense-in-depth and is not a substitute for server-side Auth policy or breached-password screening.

## 3. GitHub validation

For every release candidate:

- [x] **Validate Dukaan Dhisme POS** is green for the merged release-engineering baseline.
- [x] `flutter analyze --fatal-infos` reports `No issues found` on that baseline.
- [x] Automated Flutter tests pass.
- [x] **Validate Supabase Database** rebuilds the migration chain and passes 30/30 database tests.
- [x] Database CI performs encrypted backup, clean restore, exact manifest comparison, post-restore pgTAP, and recovery-invariant checks.
- [x] **Build Dukaan Dhisme POS Validation APK** compiles successfully on the merged release-engineering baseline.
- [x] Validation jobs no longer depend on artifact upload, avoiding the previous artifact-quota failure mode.
- [x] Validation workflow builds from the committed Android project rather than generating native files at runtime.
- [x] PR #36 recovery candidate `d7d49e3f3f749da83bead39b86fa00d4fdc53a87` passed Flutter #74, database/restore #47, and Android #181 before the final live-deployment status documentation update.

The normal PR/push workflow verifies compilation but does not retain an APK. To obtain an installable validation APK, manually run **Build Dukaan Dhisme POS Validation APK** with `workflow_dispatch`.

- [x] Manual APK workflow run succeeds on the final pilot candidate — workflow **#197, attempt 2** on `8e2f53191703085027e64f4cc2d08ac066c95afc`.
- [x] Artifact `dukaan-dhisme-pos-validation-apk` is available and its archive digest was recorded.
- [x] `BUILD_CHANNEL.txt` confirms **release mode / debug signing / non-production**; APK checksum matches `SHA256SUMS` and inspection found no embedded `sb_secret_` credential.
- [ ] APK installs on the actual Android phones intended for the pilot.
- [ ] App opens, signs in, resumes, and relaunches without crashing.

## 4. Owner and employee onboarding

> **21 Sep 2026:** dedicated production Test Manager onboarding was intentionally deferred. Backend role controls and invite lifecycle tests remain the evidence base until a dedicated manager account is created and the UI smoke test is performed.

- [ ] Owner registration creates the correct store and owner profile on the pilot environment.
- [ ] `current_user_store_id()` resolves the correct store UUID.
- [ ] Owner creates seller and manager invite codes.
- [ ] Seller/manager joins the correct store and receives the correct role.
- [ ] New Owner and employee accounts reject passwords that do not meet the strong-password rule.
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
- [x] Restored database reruns the same 30 security/RLS tests successfully.
- [ ] Confirm equivalent restrictions through the installed app with two real pilot stores/accounts.
- [ ] Confirm unauthenticated API calls cannot execute privileged business RPCs as part of release security regression testing.

## 7. Backup, recovery, and observability

- [x] Free-plan independent backup policy is documented in `docs/BACKUP_RESTORE_RUNBOOK.md`.
- [x] Encrypted logical backup and integrity-verification scripts are committed; local backup output is Git-ignored.
- [x] End-to-end encrypted restore drill completed against a clean isolated Supabase/Postgres target.
- [x] Auth/business data and migration history survived the restore and matched the source transactional manifest exactly.
- [x] Post-restore security/RLS suite passed 30/30.
- [x] Technical restore baseline measured at **37 seconds** in CI.
- [x] Pilot incident severity/escalation process is documented in `docs/OBSERVABILITY_RUNBOOK.md`.
- [ ] Perform the first encrypted **live** project backup on a secure operator machine and verify it successfully.
- [ ] Store that live encrypted backup off-site with its passphrase stored separately.
- [ ] Measure a full operator-run hosted recovery RTO if an operational SLA is required; the 37-second CI restore is only the database technical baseline.
- [ ] Configure persistent Flutter crash/error monitoring with an approved provider/privacy configuration.
- [ ] Configure operational alerts for material backend failures and backup failures.

## 8. Production Android release gate

- [x] Commit/stabilize the Android native project and Gradle wrapper.
- [x] Freeze application ID `com.dukaandhisme.dhisme_pos` and target/compile SDK 36 for this release line.
- [x] Gradle refuses a normal production release task without protected release signing credentials.
- [x] Add a manual `Produce Signed Android Release` workflow that builds APK+AAB, verifies signatures, rejects the Android Debug certificate, and produces SHA-256 checksums.
- [x] Document signing-key generation/custody and GitHub secret names in `docs/ANDROID_RELEASE_SIGNING.md`.
- [ ] Generate and securely back up the long-lived Android upload/release keystore.
- [ ] Configure `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEY_ALIAS`, `ANDROID_STORE_PASSWORD`, and `ANDROID_KEY_PASSWORD` as protected GitHub Actions secrets.
- [ ] Produce and verify the first signed APK/AAB.
- [ ] Increment app version/build number for the actual pilot/production candidate when appropriate.
- [ ] Decide whether pilot devices use debug-signed validation builds (clean reinstall required for production transition) or the long-lived signing identity (preferred when testing upgrade behavior).
- [ ] Verify release shrink/obfuscation policy.
- [ ] Test the intended transition/upgrade path on real devices.

## 9. Pilot limitations to communicate

- Offline mode is not implemented; core operation requires internet connectivity.
- PDF receipts/statements depend on compatible Android sharing/printing apps.
- Notifications are currently in-app rather than a complete push-notification/alerting system.
- Profit reporting depends on accurate buying-price data.
- Supabase leaked-password screening is unavailable on the current Free plan and is an accepted controlled-pilot limitation; strong app-side password rules are only a compensating control.
- Debug-signed validation APKs are for controlled testing and normally cannot upgrade in place to a differently signed production APK.
- Controlled-pilot technical gates are strong. Unrestricted production still requires the unchecked real-device pilot, remaining Auth configuration checks, first live encrypted backup, monitoring/alerts, and protected signing requirements above. The Free-plan leaked-password warning is documented separately as an accepted limitation rather than silently treated as cleared.

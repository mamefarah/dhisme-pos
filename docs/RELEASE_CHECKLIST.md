# Dhisme POS — Controlled Pilot Release Checklist

Run this checklist before handing a validation APK to a pilot store. A green Flutter build alone is **not** a production release approval.

---

## 1. Database reconstruction and migrations

Use the committed migration history as the source of truth. Do **not** apply only `001_init.sql` or stop at the older Phase migrations.

- [ ] Create or reset a staging Supabase project/database.
- [ ] Apply **every file in `supabase/migrations/` in filename order**, preferably with `supabase db push`.
- [ ] Confirm the current security/financial migrations (020 onward) are included, including the latest aggregate-balance protection migration.
- [ ] Confirm migration execution completes without skipped or manually edited SQL.
- [ ] Verify the reconstructed staging schema matches the intended live schema before pilot rollout.
- [ ] Test customer and supplier creation after reconstruction.
- [ ] Verify authenticated clients cannot directly INSERT or UPDATE `customers.total_balance` or `suppliers.total_balance`.
- [ ] Verify approved SECURITY DEFINER transaction RPCs can still maintain those balances.

## 2. Supabase project security

- [ ] `SUPABASE_URL` and the publishable/anon client key are supplied through GitHub Actions secrets/build-time `--dart-define`; no credentials are hardcoded in source.
- [ ] No `service_role` key is present in the Flutter application or client build pipeline.
- [ ] RLS is enabled and verified on every tenant/business table.
- [ ] Leaked-password protection is enabled before unrestricted production use.
- [ ] Authentication email/redirect settings match the intended pilot onboarding flow.
- [ ] Run Supabase security/database advisors and resolve any high-severity findings.

## 3. GitHub validation

For every release candidate:

- [ ] **Validate Dukaan Dhisme POS** is green.
- [ ] `flutter analyze --fatal-infos` reports `No issues found`.
- [ ] All automated tests pass.
- [ ] **Build Dukaan Dhisme POS Validation APK** compiles successfully.
- [ ] No GitHub Actions deprecation/storage errors remain.

The normal PR/push workflow verifies compilation but does not retain an APK. To obtain an installable validation APK, manually run **Build Dukaan Dhisme POS Validation APK** with `workflow_dispatch`.

- [ ] Manual run succeeds.
- [ ] Artifact `dukaan-dhisme-pos-unsigned-validation-apk` is available.
- [ ] `BUILD_CHANNEL.txt` confirms it is an unsigned validation build.
- [ ] APK installs on the actual Android phones intended for the pilot.
- [ ] App opens, signs in, resumes, and relaunches without crashing.

## 4. Owner and employee onboarding

- [ ] Owner registration creates the correct store and owner profile.
- [ ] `current_user_store_id()` resolves the correct store UUID.
- [ ] Owner creates seller and manager invite codes.
- [ ] Seller/manager joins the correct store and receives the correct role.
- [ ] Deactivated users cannot continue protected business operations.

## 5. Financial and operational smoke test

Run `docs/PILOT_TEST_SCRIPT.md` plus the current financial flows. At minimum verify:

- [ ] Products/categories: create, edit, prices, minimum price, stock threshold.
- [ ] Stock adjustment: add/remove stock and verify movement history.
- [ ] Supplier: create/edit supplier and record purchases.
- [ ] Purchase: paid, unpaid, and partial payment flows; supplier balance reconciles.
- [ ] Cash/bank/mobile sale completes and stock decreases once.
- [ ] Mixed payment split must exactly reconcile to sale total.
- [ ] Credit request enforces customer credit controls and approval rules.
- [ ] Customer payment allocates correctly and customer debt reconciles.
- [ ] Supplier payment allocates correctly and supplier debt reconciles.
- [ ] Full and partial returns restore stock and reconcile exact cumulative refunds.
- [ ] Expenses appear in the financial ledger and reports.
- [ ] Seller/manager daily cash closing matches the net ledger.
- [ ] Sales, returns, COGS, gross profit, expenses, and net profit reconcile to a manual sample.
- [ ] Retry/double-tap tests do not create duplicate sales, payments, purchases, expenses, or returns.

## 6. Role and tenant security spot-check

Test with at least two stores and Owner/Manager/Seller accounts.

- [ ] Store A users cannot read or mutate Store B data.
- [ ] Seller cannot access owner/manager-only reports, statements, supplier mutations, or approvals.
- [ ] Seller cannot change customer credit controls.
- [ ] Direct PostgREST attempts to alter aggregate customer/supplier debt balances fail.
- [ ] Direct client writes to immutable financial ledger/allocation tables fail.
- [ ] Unauthenticated users cannot execute privileged business RPCs.

## 7. Backup, recovery, and observability

Required before unrestricted production rollout:

- [ ] Database backup policy is configured and documented.
- [ ] A restore drill has been completed against a non-production project.
- [ ] Crash/error monitoring is configured for the Flutter app.
- [ ] Operational alerts exist for material backend failures.
- [ ] A support/escalation process exists for reconciliation or data-integrity incidents.

## 8. Production Android release gate

The current GitHub APK is an **unsigned validation build**. Do not distribute it as the final production release.

Before production:

- [ ] Commit/stabilize the intended Android native project configuration rather than relying on ad-hoc release changes.
- [ ] Configure protected Android signing credentials/secrets.
- [ ] Produce and verify a signed release APK/AAB.
- [ ] Increment app version/build number for each release candidate.
- [ ] Verify package/application ID, target/compile SDK, permissions, backup settings, and release shrink/obfuscation policy.
- [ ] Test upgrade from the pilot build to the signed production build without data/session surprises.

## 9. Pilot limitations to communicate

- Offline mode is not implemented; core operation requires internet connectivity.
- PDF receipts/statements depend on compatible Android sharing/printing apps.
- Notifications are currently in-app rather than a complete push-notification/alerting system.
- Profit reporting depends on accurate buying-price data.
- Pilot deployment remains controlled until the production release, backup/restore, monitoring, and operational gates above are complete.

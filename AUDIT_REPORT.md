# Dukaan Dhisme POS — Security & Architectural Audit Report

This report summarizes the repository-level security, architecture, transactional-integrity, Flutter quality, database validation, and release-readiness review of **Dukaan Dhisme POS** (Flutter + Supabase).

## 1. Executive summary

### Overall assessment: **Technically ready for a controlled pilot — not unrestricted production-ready**

The application has a strong multi-tenant and server-side financial architecture, including RLS, role-aware SECURITY DEFINER RPCs, idempotency protection, row locking, an immutable money ledger, exact return reconciliation, server-side reporting, strict Flutter analyzer gates, Android release-mode compilation, and automated database migration/RLS testing.

The code/database remediation from PR #31 and PR #32 is now merged. The complete committed migration chain through migration 029 has been reconstructed successfully on an isolated local Supabase/Postgres environment, the database security/RLS pgTAP suite passed 30/30 tests, and the aggregate-balance hardening was deployed to the connected Supabase project and verified with rollback-safe authenticated owner/seller tests.

This is still not an unconditional production approval. Real-device pilot testing, leaked-password protection, backup/restore validation, production signing, and monitoring/operational readiness remain release gates.

## 2. Backend and database security

### 2.1 Tenant isolation and RLS

Business data is scoped to the authenticated user's store using RLS and helper functions such as `current_user_store_id()` and `current_user_role()`. Privileged business mutations are implemented through server-side RPCs rather than trusting financial values supplied by the Flutter client.

The automated database test gate now rebuilds the full migration chain on an isolated database and verifies owner/seller permissions, cross-store isolation, customer/supplier flows, and trusted RPC behavior on every relevant pull request.

### 2.2 Financial mutation controls

The current remediation chain includes:

- immutable ledger/allocation tables with direct client mutation privileges revoked;
- idempotency keys for retry-safe financial operations;
- row locking for stock and credit-sensitive operations;
- server-side validation for mixed payments, discounts, minimum selling price, purchase payments, credit exposure, returns, and cash closing;
- FIFO customer/supplier payment allocation;
- exact cumulative refund handling for partial returns;
- server-side reporting that accounts for returns, COGS, expenses, and debt balances.

### 2.3 Aggregate customer/supplier balance protection

PR #30 correctly identified that broad customer/supplier table privileges could allow a crafted client request to manipulate aggregate `total_balance` values even when normal UI flows used RPCs.

Migration `20260808043000_028_protect_financial_balances.sql` moves that protection to the PostgreSQL privilege layer:

- broad authenticated INSERT/UPDATE privileges on `customers` and `suppliers` are revoked;
- authenticated users receive only the specific column privileges required by legitimate direct edits;
- `customers.total_balance` and `suppliers.total_balance` are excluded from both INSERT and UPDATE grants;
- supplier `store_id` is resolved server-side for the existing supplier-creation flow;
- migration assertions fail if aggregate balance columns remain directly writable.

The first clean reconstruction exposed a portability gap: an explicit authenticated SELECT grant on `customers`/`suppliers` could not be assumed from older migration history. Migration `20260808050000_029_restore_customer_supplier_select.sql` therefore restores the read access required by normal RLS-filtered application queries without re-opening aggregate balance writes.

The combined hardening was deployed to the connected Supabase project. Post-deployment verification confirmed:

- authenticated SELECT remains available on customers and suppliers;
- authenticated direct INSERT/UPDATE of customer/supplier `total_balance` is denied;
- clients cannot choose `suppliers.store_id` directly;
- legitimate owner customer/supplier operations continue to work;
- seller customer creation still works while seller customer updates/supplier creation remain restricted;
- cross-store customer visibility/inserts remain blocked;
- `record_purchase_v2` can still maintain supplier balance and stock through its trusted SECURITY DEFINER transaction;
- all live verification mutations were wrapped in transactions and rolled back, leaving no test customer, supplier, purchase, or stock change behind.

## 3. Flutter client quality

The application uses a feature-oriented structure with repositories separating screens from Supabase access. The remediation modernized Flutter 3.44.1 compatibility by:

- using `publishableKey` for Supabase initialization;
- replacing deprecated `DropdownButtonFormField.value` usage with `initialValue`;
- migrating deprecated per-tile Radio selection state to `RadioGroup` ancestors;
- guarding verified async navigation/context gaps;
- aligning supplier Edit/Pay UI actions with owner/manager roles.

CI runs `flutter analyze --fatal-infos`; analyzer info-level regressions therefore fail validation instead of being silently accepted.

## 4. CI, database, and Android validation

The repository now maintains three complementary gates:

- **Validate Dukaan Dhisme POS** — package resolution, fatal-info analyzer, and automated Flutter tests.
- **Build Dukaan Dhisme POS Validation APK** — Android SDK setup, analyzer/tests, and release-mode APK compilation.
- **Validate Supabase Database** — isolated local Supabase reconstruction of all committed migrations plus pgTAP database/RLS/security tests.

For the final database-gate remediation head:

- Flutter validation passed;
- Android release-mode validation build passed;
- migrations 001 through 029 rebuilt successfully from scratch;
- the database security/RLS suite passed **30/30** tests.

Normal PR/push Android jobs prove compilation but do not retain an APK. A downloadable unsigned validation APK is retained only for an explicit manual (`workflow_dispatch`) run, reducing GitHub Actions artifact-storage pressure.

The validation APK remains intentionally unsigned and is **not** the final production distribution artifact.

## 5. Post-deployment advisor status

The Supabase security advisor continues to report warnings that authenticated users can execute SECURITY DEFINER functions. For this application, authenticated access to many business RPCs is intentional: the functions are the server-side transaction boundary and enforce role/store/business checks internally. These warnings should remain on an explicit reviewed allowlist rather than being dismissed globally.

The advisor also reports that leaked-password protection is disabled. That is a real remaining authentication-hardening gate and should be enabled before unrestricted production rollout.

Performance advisor `unused_index` notices are informational on this small/lightly used database and are not sufficient evidence to remove indexes that support expected production query paths.

## 6. Remaining release risks and gates

| Area | Current status | Remaining requirement |
| --- | --- | --- |
| Multi-tenant RLS / RPC architecture | **Validated** by isolated reconstruction and role/tenant tests | Continue regression testing on future migrations |
| Aggregate customer/supplier balances | **Deployed and verified** | Keep migrations 028/029 and negative tests in CI |
| Flutter analyzer | **Green** under fatal infos | Keep as required PR gate |
| Automated Flutter tests | **Green** | Expand integration/widget coverage over time |
| Database migration/RLS tests | **30/30 green** | Keep as required PR gate |
| Android release-mode compile | **Green** | Keep as release-candidate gate |
| Real-device pilot | Not yet recorded complete | Run the full 32-scenario pilot script on intended phones/accounts |
| Authentication hardening | Incomplete | Enable leaked-password protection |
| Backup/recovery | Incomplete | Configure/document backup policy and complete a restore drill |
| Monitoring | Incomplete | Add Flutter crash/error monitoring and backend operational alerts |
| Production Android distribution | Unsigned validation only | Configure protected signing and produce/verify signed APK/AAB |
| Offline mode | Not implemented | Keep pilot online-only unless requirements change |

## 7. Audit verdict

**Approved for controlled-pilot execution from a code, CI, and database-integrity perspective.**

This approval assumes the pilot is monitored and reconciled and does not substitute for the remaining operational gates. Unrestricted production rollout should wait until real-device pilot testing, authentication hardening, backup/restore, monitoring, and signed Android release requirements in `docs/RELEASE_CHECKLIST.md` are completed.

# Dukaan Dhisme POS — Security & Architectural Audit Report

This report summarizes the repository-level security, architecture, transactional-integrity, Flutter quality, and release-readiness review of **Dukaan Dhisme POS** (Flutter + Supabase).

## 1. Executive summary

### Overall assessment: **Controlled-Pilot Candidate — not unrestricted production-ready**

The application has a strong multi-tenant and server-side financial architecture, including RLS, role-aware SECURITY DEFINER RPCs, idempotency protection, row locking, an immutable money ledger, exact return reconciliation, and server-side reporting. The remediation branch also addresses the remaining Flutter SDK deprecations and the P1 aggregate-balance privilege finding from PR #30.

The application must still pass the release gates in `docs/RELEASE_CHECKLIST.md` before unrestricted production use. In particular, production signing, clean database reconstruction, backup/restore validation, leaked-password protection, real-device end-to-end testing, and crash/operational monitoring remain operational release requirements.

## 2. Backend and database security

### 2.1 Tenant isolation and RLS

Business data is scoped to the authenticated user's store using RLS and helper functions such as `current_user_store_id()` and `current_user_role()`. Privileged business mutations are implemented through server-side RPCs rather than trusting financial values supplied by the Flutter client.

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

Migration `20260808043000_028_protect_financial_balances.sql` addresses this at the PostgreSQL privilege layer:

- broad authenticated INSERT/UPDATE privileges on `customers` and `suppliers` are revoked;
- authenticated users receive only the specific column privileges required by legitimate direct profile/contact edits;
- `customers.total_balance` and `suppliers.total_balance` are excluded from both INSERT and UPDATE grants;
- a migration assertion fails if those aggregate columns remain directly writable;
- supplier `store_id` is resolved server-side for the existing supplier-creation flow.

This design does not depend on `current_user` checks inside a SECURITY DEFINER trigger and covers both creation and later updates.

## 3. Flutter client quality

The application uses a feature-oriented structure with repositories separating screens from Supabase access. The remediation branch modernizes Flutter 3.44.1 compatibility by:

- using `publishableKey` for Supabase initialization;
- replacing deprecated `DropdownButtonFormField.value` usage with `initialValue`;
- migrating deprecated per-tile Radio selection state to `RadioGroup` ancestors;
- guarding verified async navigation/context gaps;
- aligning supplier Edit/Pay UI actions with owner/manager roles.

The CI quality gate now runs `flutter analyze --fatal-infos`, so an analyzer info-level regression fails the PR rather than being silently accepted. The final audit status should only be considered validated when the GitHub Actions checks for the exact PR head are green.

## 4. CI and Android validation

The repository keeps separate quality and Android-build workflows:

- **Validate Dukaan Dhisme POS**: package resolution, analyzer, and automated tests.
- **Build Dukaan Dhisme POS Validation APK**: Android SDK setup, analyzer/tests, and release-mode APK compilation.

The remediation changes also reduce GitHub Actions storage pressure: PR/push builds still prove the APK compiles, but the downloadable APK artifact is uploaded only for an explicit manual (`workflow_dispatch`) run and retained for one day.

The validation APK remains intentionally unsigned and is **not** the final production distribution artifact.

## 5. Remaining release risks and gates

| Area | Repository status | Release requirement |
| --- | --- | --- |
| Multi-tenant RLS / RPC architecture | Strong, subject to staging verification | Reconstruct clean staging DB and run cross-store tests |
| Aggregate customer/supplier balances | Remediation committed in migration 028 | Apply migration and run direct PostgREST negative tests |
| Flutter analyzer | Fatal-info gate enabled | Exact PR head must report `No issues found` |
| Automated tests | Existing financial-rule tests plus CI | Expand integration/RLS coverage over time |
| Android compile | CI validation workflow | Exact PR head must build successfully |
| APK distribution | Unsigned validation only | Configure protected production signing and signed APK/AAB |
| Authentication hardening | Partially operational | Enable leaked-password protection before unrestricted production |
| Backup/recovery | Operational task | Complete and document restore drill |
| Monitoring | Operational task | Add crash/error monitoring and backend alerting |
| Offline mode | Not implemented | Keep controlled pilot online-only unless requirements change |

## 6. Audit verdict

**Approved to continue through controlled-pilot validation once the exact remediation PR head passes CI and the migration is verified on staging.**

This is not an unconditional production approval. Production rollout should occur only after the signing, database reconstruction, backup/restore, monitoring, authentication-hardening, and real-device operational gates in `docs/RELEASE_CHECKLIST.md` are completed.

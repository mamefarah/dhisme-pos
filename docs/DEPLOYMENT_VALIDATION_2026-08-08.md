# Dukaan Dhisme POS — Deployment Validation Record

**Date:** 08 Aug 2026  
**Scope:** PR #31 remediation, PR #32 database validation gate, aggregate customer/supplier balance hardening, live rollback-safe verification.

## Repository validation

The following GitHub validation completed successfully before the database hardening was deployed:

- `Validate Dukaan Dhisme POS` — analyzer and Flutter tests passed.
- `Build Dukaan Dhisme POS Validation APK` — release-mode Android compilation passed.
- `Validate Supabase Database` — the complete committed migration chain reconstructed successfully on an isolated local Supabase/Postgres environment.
- Database pgTAP security/RLS suite — **30/30 tests passed**.

The database gate covers aggregate-balance privileges, customer/supplier RLS, owner/seller behavior, cross-store isolation, supplier store assignment, and trusted SECURITY DEFINER purchase behavior.

## Migration finding and correction

Migration 028 correctly removed direct authenticated INSERT/UPDATE access to `customers.total_balance` and `suppliers.total_balance`, but the first clean reconstruction exposed that authenticated SELECT access to `customers`/`suppliers` could not be assumed from older migration history.

Migration 029 was added to explicitly restore RLS-filtered SELECT access while preserving server ownership of aggregate balance columns.

A second clean reconstruction applied migrations 001 through 029 successfully and the full 30-test database suite passed.

## Live Supabase deployment

The validated aggregate-balance hardening was applied to the connected `dhisme-pos` Supabase project as the remote migration:

`protect_financial_balances_and_restore_select`

The live deployment was then verified using authenticated-role simulations inside explicit transactions followed by rollback.

Verified outcomes:

- authenticated users can SELECT customers and suppliers subject to RLS;
- authenticated clients cannot directly INSERT/UPDATE customer aggregate balance;
- authenticated clients cannot directly INSERT/UPDATE supplier aggregate balance;
- authenticated clients cannot directly choose `suppliers.store_id`;
- legitimate owner customer/supplier operations continue to work;
- supplier creation receives the authenticated store through the server-side default;
- seller can create same-store customers;
- seller cannot update protected customer fields through owner/manager UPDATE policy;
- seller cannot create suppliers;
- cross-store customer data remains invisible and cross-store insert attempts are blocked;
- `record_purchase_v2` remains able to update supplier debt and stock as a trusted server-side transaction.

All verification mutations were rolled back. Post-test checks confirmed that no verification customers, suppliers, or purchases remained and the tested product stock was unchanged.

## Supabase advisor review

After deployment, the security advisor was reviewed.

Remaining warnings fall into two categories:

1. **Authenticated SECURITY DEFINER functions.** Many are intentional application RPC endpoints and are the server-side authorization/transaction boundary. They must remain on a reviewed allowlist and should not be blindly revoked solely to silence the generic advisor warning.
2. **Leaked-password protection disabled.** This remains a real authentication-hardening task before unrestricted production rollout.

Performance advisor unused-index notices are informational in the currently small/lightly used database and are not, by themselves, justification for removing indexes intended for expected production query paths.

## Current release decision

**Code, CI, migration reproducibility, core database privilege hardening, and tenant-role database checks are green for controlled-pilot execution.**

Unrestricted production is still blocked by operational gates recorded in `docs/RELEASE_CHECKLIST.md`, especially:

- real-device completion of the full pilot script;
- leaked-password protection;
- backup/restore drill;
- crash/error monitoring and operational alerting;
- protected Android production signing and signed APK/AAB verification.

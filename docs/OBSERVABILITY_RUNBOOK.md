# Dukaan Dhisme POS — Pilot Observability & Incident Runbook

## Current status

Backend operational logs are available through Supabase for recent Auth, API, Postgres, Storage, Realtime, and Edge Function activity. The Flutter app does **not yet have a persistent third-party crash-reporting provider configured**.

This runbook defines the minimum controlled-pilot process. Persistent mobile crash reporting remains a production gate rather than being falsely marked complete.

## Pilot monitoring cadence

During the pilot, review the following at least once per operating day and immediately after any reported incident:

- Supabase Auth logs for failed sign-in/signup patterns and rate-limit errors;
- API/PostgREST logs for 4xx/5xx database/API failures;
- Postgres logs for transaction, constraint, permission, or timeout failures;
- GitHub Actions status for any new release candidate;
- owner/manager reconciliation results for sales, payments, expenses, purchases, returns, and cash closing.

## Severity levels

### SEV-1 — stop financial operations

Examples:

- cross-store data exposure;
- duplicated or missing financial transactions;
- unexplained stock/debt mutation;
- data corruption;
- unauthorized owner/manager operation;
- inability to reconcile the cash ledger materially.

Action:

1. Stop new pilot transactions on the affected store/account.
2. Preserve screenshots, invoice IDs, user, time, store, and transaction references.
3. Take an encrypted database backup before corrective database work where possible.
4. Review Supabase/API/Postgres logs.
5. Reproduce only in an isolated/local database when possible.
6. Do not edit financial rows manually without a documented reconciliation plan.
7. Record resolution and verification before reopening operations.

### SEV-2 — degraded but financially contained

Examples:

- one screen fails while data remains intact;
- PDF/share failure;
- non-financial UI crash;
- intermittent connectivity issue with no duplicate transaction.

Action:

- capture reproduction steps;
- verify server-side transaction state before retrying;
- open/fix through normal release workflow;
- retest the affected pilot scenario.

### SEV-3 — cosmetic/minor

Examples:

- layout/text issue;
- non-blocking translation issue;
- minor usability problem.

Track for normal maintenance unless it causes users to make incorrect financial choices.

## Required incident record

For every SEV-1/SEV-2 incident record:

- date/time and timezone;
- app version/build;
- user role;
- store;
- device/Android version;
- action being performed;
- sale/payment/purchase/return/customer/supplier identifiers where applicable;
- screenshot/error message;
- network state;
- whether the user retried/tapped twice;
- observed database state;
- root cause;
- corrective change/PR;
- reconciliation performed;
- retest result.

Never place passwords, API secret keys, database passwords, or full customer-sensitive data in an issue or screenshot.

## Crash reporting production gate

Before unrestricted production, integrate a persistent Flutter crash/error monitoring provider and configure it with protected build-time/runtime configuration.

Minimum requirements:

- uncaught Flutter framework errors captured;
- uncaught asynchronous/platform errors captured;
- release version/build attached;
- environment/channel attached (pilot vs production);
- user/store identifiers minimized or pseudonymized;
- no passwords, access tokens, API keys, invoice-sensitive payloads, or customer PII sent unnecessarily;
- alerting for new fatal crashes and material error-rate spikes;
- source-map/symbol handling appropriate to any obfuscation policy.

Do not add a monitoring SDK merely to satisfy a checkbox. Choose/configure the provider and data-retention/privacy settings first, then test a controlled non-sensitive crash in a non-production build.

## Backend alerting production gate

For unrestricted production, define alerts for at least:

- repeated Auth failures/rate limiting above expected levels;
- sustained API 5xx errors;
- database resource exhaustion/timeouts;
- failed scheduled backup/verification process;
- recurring reconciliation anomalies.

The exact alert mechanism depends on the selected Supabase plan and monitoring stack.

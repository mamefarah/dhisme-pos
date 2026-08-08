# Dukaan Dhisme POS — Controlled Pilot Execution Plan

## Objective

Validate Dukaan Dhisme POS under real Android usage with Owner, Manager, and Seller roles while limiting financial/data risk and collecting enough evidence for a production decision.

## Entry gates

Do not start the real-device pilot until:

- PR #34 exact-head Flutter, database, and Android validation checks are green;
- the intended pilot signing path is chosen;
- an encrypted database backup has been created and verified;
- the pilot store/accounts and test boundaries are agreed;
- the operator has `docs/PILOT_TEST_SCRIPT.md`, this plan, and the incident runbook available.

## Choose the pilot signing path

### Option A — long-lived signing identity (preferred)

Generate and protect the Android upload/release key first, configure GitHub release secrets, and create the pilot candidate with that signing identity. This provides the cleanest test of future upgrade behavior.

### Option B — debug-signed validation APK

Use the manual validation APK workflow. This is appropriate for functional testing, but the later differently signed production APK will normally require uninstall/reinstall on the same application ID.

Record the choice before installation.

## Pilot scope

Use a controlled set of users and devices:

- at least one Owner account;
- at least one Manager account;
- at least one Seller account;
- where feasible, two separate test stores for visible tenant-isolation checks;
- actual Android phones representative of intended daily use.

Start with test/low-risk transactions before allowing meaningful business volume.

## Day 0 — installation and onboarding

Record for every device:

- phone model;
- Android version;
- app version/build;
- installation method;
- signing channel;
- assigned user/role.

Verify:

1. installation succeeds;
2. app launches without crash;
3. language toggle works;
4. Owner signup/sign-in works;
5. strong-password policy is enforced for new accounts;
6. email confirmation/onboarding behaves as intended;
7. Owner creates Manager/Seller invite codes;
8. employee joins the correct store;
9. app relaunch retains a valid session;
10. deactivated-user behavior is correct.

## Day 1 — master data and purchasing

Run the relevant scenarios in `PILOT_TEST_SCRIPT.md` and verify:

- categories/products;
- buying/selling/minimum prices;
- initial/manual stock adjustments;
- supplier create/edit authorization;
- paid purchase;
- unpaid purchase;
- partial purchase;
- supplier debt and payment allocation;
- stock movement history.

Reconcile the database-visible totals against a manual calculation before proceeding.

## Day 2 — sales, customer credit, and returns

Verify:

- cash sale;
- bank sale;
- mobile-money sale;
- mixed payment;
- price-floor behavior;
- customer create/edit;
- credit controls;
- seller credit request;
- owner/manager approval decision;
- customer payment allocation;
- partial return;
- full/cumulative return;
- exact stock/debt/refund reconciliation.

Repeat selected actions with deliberate double-tap/retry/network interruption to confirm idempotency prevents duplicates.

## Day 3 — expenses, cash closing, and reports

Verify:

- expense creation and ledger effect;
- cash adjustment controls where applicable;
- seller/manager closing workflow;
- closing review;
- sales summary;
- returns;
- COGS/gross profit;
- expenses/net profit;
- customer/supplier statements;
- daily cash reconciliation.

Manually reconcile a sample day from source transactions to reports.

## Security spot-check

Using real pilot accounts:

- Seller cannot use Owner/Manager-only supplier/customer-credit actions.
- Store A user cannot see Store B business data.
- Deactivated user loses protected access.
- Direct client aggregate-balance editing remains unavailable.
- No service-role/administrative credential exists on the phone.

Do not conduct destructive security experimentation against meaningful live data.

## Daily operating procedure during pilot

### Before opening

- confirm internet connectivity;
- confirm app opens/signs in;
- check prior-day closing/reconciliation status;
- confirm no unresolved SEV-1 incident;
- confirm last encrypted backup verification passed.

### During operation

- record unusual error messages immediately;
- do not repeatedly retry an uncertain financial transaction until server state is checked;
- capture transaction/reference IDs for incidents;
- avoid manual database edits.

### End of day

1. complete cash/financial reconciliation;
2. review any failed/duplicate-looking operations;
3. review recent Supabase logs when incidents occurred;
4. create encrypted database backup;
5. verify backup integrity;
6. store backup off-site;
7. update pilot pass/fail log.

## Pilot failure criteria

Pause affected financial operations for:

- unexplained duplicate/missing financial transaction;
- cross-store data exposure;
- unreconciled stock/debt/cash mutation;
- unauthorized privileged action;
- repeatable crash blocking a core financial workflow;
- evidence of data corruption.

Follow `docs/OBSERVABILITY_RUNBOOK.md` for incident handling.

## Pilot exit criteria

The controlled pilot is considered technically successful when:

- all critical scenarios in `PILOT_TEST_SCRIPT.md` pass on real devices;
- Owner/Manager/Seller authorization behaves correctly;
- transaction retry/idempotency checks pass;
- sample financial reconciliation has no unexplained variance;
- no open SEV-1 data-integrity/security incident remains;
- encrypted backups have been produced and verified throughout the pilot;
- at least one non-production restore drill has passed;
- the intended production signing workflow has produced a verified signed APK/AAB;
- persistent crash/error monitoring and material backend alerting are configured before unrestricted rollout;
- Supabase Auth plan/configuration limitations are explicitly accepted or resolved.

## Evidence to retain

Keep a release folder containing:

- release commit SHA;
- app version/build;
- APK/AAB SHA-256 values;
- pilot device list;
- completed test script;
- reconciliation sample;
- incident records and resolutions;
- backup verification records;
- restore-drill record;
- final release decision.

Do not put passwords, API secrets, database credentials, or unnecessary customer PII in the evidence folder.

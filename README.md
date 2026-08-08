# Dukaan Dhisme POS

Flutter + Supabase point-of-sale, inventory, credit, purchasing, supplier, expense, return, reporting, and cash-reconciliation application for construction-materials stores.

## Current capabilities

- Owner, manager, and seller authentication and role routing
- Store-isolated products, categories, customers, suppliers, employees, and notifications
- Cash, bank, mobile-money, mixed-payment, and credit-request sales
- Owner credit approval with approval-time credit-limit recheck
- Stock-in from purchases and stock-out from sales
- Customer debt, invoice allocations, payments, and statement PDF
- Supplier debt, purchase allocations, and supplier payments
- Expenses and immutable financial ledger entries
- Full and partial returns with stock restoration and exact cumulative refund accounting
- Seller and manager daily cash closing from net ledger movements
- Server-side sales, returns, profit, expense, and top-product reporting
- Receipt PDF generation and sharing
- Somali and English interface support

## Architecture

```text
Flutter Android application
  ├── Owner mode
  ├── Manager mode
  └── Seller mode
          ↓
Supabase Auth
          ↓
PostgreSQL + RLS + SECURITY DEFINER RPCs
          ↓
Sales, stock, allocations, returns, expenses, cash ledger, reports
```

Financial mutations are performed through PostgreSQL RPCs. Direct client writes to protected financial state are restricted. Store and role checks are enforced in the database rather than relying only on hidden Flutter screens.

## Repository structure

```text
lib/
  core/
  features/
android/                    # committed native project + Gradle wrapper
supabase/
  migrations/
  tests/
  seed.sql
test/
scripts/
  backup_supabase.sh
  verify_supabase_backup.sh
  generate_android_upload_key.sh
docs/
  RELEASE_CHECKLIST.md
  PILOT_TEST_SCRIPT.md
  CONTROLLED_PILOT_EXECUTION_PLAN.md
  BACKUP_RESTORE_RUNBOOK.md
  ANDROID_RELEASE_SIGNING.md
  OBSERVABILITY_RUNBOOK.md
.github/workflows/
  validate.yml
  database-tests.yml
  build-apk.yml
  production-release.yml
```

## Supabase setup

Use a development/staging environment before introducing schema changes to production.

### Recommended: Supabase CLI

```bash
supabase link --project-ref YOUR_PROJECT_REF
supabase db push
```

`supabase db push` must apply **all** files under `supabase/migrations/` in filename order. Running only `001_init.sql` is not sufficient for the current application.

The repository database CI reconstructs the full migration chain and runs the pgTAP RLS/security suite on an isolated local Supabase/Postgres environment.

After migrations:

1. Review Supabase Database/Security Advisors.
2. Confirm Row Level Security is enabled.
3. Confirm anonymous users cannot execute protected business RPCs.
4. Verify authenticated clients cannot directly write customer/supplier aggregate debt balances.
5. Review the intentional authenticated SECURITY DEFINER RPC allowlist rather than blindly exposing/revoking functions.
6. Configure the strongest Supabase Auth password protections supported by the selected plan.
7. Create/register the initial owner through the application.
8. Use store invitations for managers and sellers.
9. Create and verify an independent encrypted database backup before relying on irreplaceable transaction data.

The connected project is currently on the Supabase **Free plan**. Supabase leaked-password screening is currently a Pro+ feature, so the app enforces a compensating 12+ character mixed-character password policy at account creation. That client-side rule does **not** replace server-side breached-password screening.

Do not place a Supabase `service_role` key in Flutter, GitHub source, APK build arguments, or user documentation.

## Flutter setup

Requirements:

- Flutter 3.44.1
- Dart version bundled with Flutter 3.44.1
- Java 17
- Android SDK/compile SDK 36

```bash
flutter pub get
flutter analyze --fatal-infos
flutter test --coverage
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_OR_LEGACY_ANON_KEY
```

The Supabase URL and publishable/legacy anon key are public client configuration values. They do not replace RLS, role checks, or secure RPC design.

## Transaction controls

The audited transaction API provides:

- Client-generated idempotency keys for retry-safe operations
- Row locking for stock, customer, supplier, sale, purchase, and return updates
- Mixed-payment split validation
- Minimum effective selling-price enforcement
- Seller and manager discount limits
- Customer payment allocation to credit invoices
- Supplier payment allocation to purchases
- Actual paid amount for partial purchases
- Cumulative return-quantity enforcement
- Exact final-cent reconciliation across multiple partial returns
- Refund and expense entries in the financial ledger
- Server-side net revenue and profit reporting
- Cash closing based on all recorded inflows and outflows assigned to the user

## GitHub quality gates

### Flutter quality

`.github/workflows/validate.yml` runs on pull requests and verifies:

```text
operational shell script syntax
flutter pub get
flutter analyze --fatal-infos
flutter test --coverage
```

### Database quality

`.github/workflows/database-tests.yml`:

- reconstructs the committed Supabase migration chain from scratch;
- runs the 30-test database security/RLS suite;
- exercises the encrypted logical-backup script against the isolated database;
- decrypts/verifies that backup to prove archive integrity.

### Android validation build

`.github/workflows/build-apk.yml` builds directly from the committed `android/` project.

Normal PR and `main` push runs prove release-mode APK compilation without retaining an artifact. To obtain a downloadable test build, manually run **Build Dukaan Dhisme POS Validation APK**.

Manual artifact name:

```text
dukaan-dhisme-pos-validation-apk
```

The artifact is **release mode but debug-signed**, contains `BUILD_CHANNEL.txt` and `SHA256SUMS`, is retained for one day, and is strictly non-production.

## Production Android release

The native Android project, Gradle wrapper, application ID, compile SDK, target SDK, and signing behavior are now committed and explicit.

Application ID:

```text
com.dukaandhisme.dhisme_pos
```

A normal production release task fails closed when protected release-signing credentials are missing. The manual **Produce Signed Android Release** workflow requires protected keystore secrets, builds signed APK+AAB outputs, verifies signatures, rejects the Android Debug certificate, and creates SHA-256 checksums/release metadata.

See `docs/ANDROID_RELEASE_SIGNING.md` before creating or storing the long-lived signing key.

## Backup and recovery

The Free-plan pilot uses independent encrypted logical backups rather than assuming dashboard recovery is available.

Use:

```bash
bash scripts/backup_supabase.sh
bash scripts/verify_supabase_backup.sh <encrypted-backup-file>
```

The backup script exports roles, schema, data, and Supabase migration history, then encrypts the archive using AES-256-CBC/PBKDF2 and creates checksums.

See `docs/BACKUP_RESTORE_RUNBOOK.md`. A real backup and non-production restore drill remain required operational gates.

## Controlled-pilot validation

Before handing an APK to a pilot store:

1. Exact release-candidate Flutter, database, and Android checks are green.
2. Choose the pilot signing path: long-lived release identity (preferred for upgrade testing) or disposable debug-signed validation build.
3. Create and verify an encrypted database backup.
4. Complete `docs/PILOT_TEST_SCRIPT.md` on real Android devices and roles.
5. Exercise two-store isolation and role restrictions.
6. Manually reconcile controlled financial samples.
7. Complete device lifecycle/connectivity smoke tests.
8. Follow the daily backup and incident procedures during the pilot.

See `docs/CONTROLLED_PILOT_EXECUTION_PLAN.md` and `docs/RELEASE_CHECKLIST.md`.

## Current release status

Current app version: **1.2.0+3 controlled-pilot release-engineering candidate**.

Completed technical gates include:

- production-readiness code remediation;
- live aggregate-debt privilege hardening;
- full migration reconstruction and 30/30 database tests;
- committed Android native project and Gradle wrapper;
- explicit validation-vs-production signing separation;
- fail-closed production signing configuration;
- protected signed APK/AAB workflow structure;
- strong account-creation password policy;
- encrypted backup/verification tooling;
- controlled-pilot, backup/recovery, signing, and incident runbooks.

Unrestricted production still requires operational/account actions that cannot be truthfully marked complete in source code alone:

- real-device completion of the controlled pilot;
- first verified live encrypted backup and non-production restore drill;
- production Android keystore creation/custody and GitHub signing secrets;
- first verified signed APK/AAB;
- persistent Flutter crash/error monitoring and material backend alerting;
- Supabase Auth production-hardening decision, including upgrading if leaked-password screening is required.

Until those gates are complete, use controlled-pilot procedures with reconciliation and backups.

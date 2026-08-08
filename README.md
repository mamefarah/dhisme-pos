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
supabase/
  migrations/
  seed.sql
test/
docs/
  RELEASE_CHECKLIST.md
  PILOT_TEST_SCRIPT.md
.github/workflows/
  validate.yml
  build-apk.yml
```

## Supabase setup

Use a new development or staging project before production.

### Recommended: Supabase CLI

```bash
supabase link --project-ref YOUR_PROJECT_REF
supabase db push
```

`supabase db push` must apply **all** files under `supabase/migrations/` in filename order. Running only `001_init.sql` is not sufficient for the current application.

After the migrations:

1. Review Supabase Database Advisors.
2. Confirm Row Level Security is enabled.
3. Confirm anonymous users cannot execute protected business RPCs.
4. Verify authenticated clients cannot directly write customer/supplier aggregate debt balances.
5. Enable leaked-password protection in Supabase Authentication settings before unrestricted production use.
6. Create or register the initial owner through the application.
7. Use store invitations for managers and sellers.
8. Test backup and restore before using irreplaceable transaction data.

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

## GitHub quality gate

`.github/workflows/validate.yml` runs on pull requests and performs:

```text
flutter pub get
flutter analyze --fatal-infos
flutter test --coverage
```

Analyzer infos are treated as failures. Diagnostic artifacts are retained only for failed validation runs to reduce Actions storage usage.

## Android validation build

`.github/workflows/build-apk.yml` verifies that the app can compile as a release-mode Android APK after analyzer and test checks.

Normal PR and `main` push runs verify compilation without retaining the APK. To obtain a downloadable validation APK, manually run **Build Dukaan Dhisme POS Validation APK** from GitHub Actions.

Manual artifact name:

```text
dukaan-dhisme-pos-unsigned-validation-apk
```

The manual artifact contains a `BUILD_CHANNEL.txt` warning, is retained briefly, and is **not a signed production release**.

A production-distribution workflow must:

- Require protected signing credentials
- Fail when signing credentials are missing
- Verify the signing certificate
- Protect the keystore outside the repository
- Use an incremented version/build number
- Produce a clearly named signed production APK/AAB

## Controlled-pilot validation

Before handing an APK to a pilot store:

1. PR validation and Android compilation are green for the exact release-candidate commit.
2. A clean staging database is reconstructed from every committed migration.
3. `docs/PILOT_TEST_SCRIPT.md` is completed, including two-store isolation, aggregate-balance tampering, mixed payments, purchases, supplier/customer allocations, returns, expenses, cash closing, and idempotency tests.
4. Financial reports are manually reconciled against a controlled sample.
5. Backup/restore has been tested.
6. Real Android devices complete lifecycle/connectivity smoke tests.

See `docs/RELEASE_CHECKLIST.md` for the full release gate.

## Current release status

Current app version: **1.1.0+2 controlled-pilot candidate**.

The project has undergone substantial Red Team remediation and production-readiness hardening. Core financial integrity, anonymous RPC exposure, aggregate customer/supplier balance privileges, Flutter SDK deprecations, and CI quality gates are addressed in the current remediation candidate.

Unrestricted production deployment still requires:

- A clean green merge of the validated remediation pull request
- Fresh staging-database reconstruction from committed migrations
- Completion of the expanded controlled-pilot test script
- Leaked-password protection enabled
- Tested backup/restore procedures
- A signed production release workflow and store-owned release key
- Crash/error monitoring and operational alerting

Until those conditions are met, use only a controlled pilot with reconciliation and backups.

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
- Full and partial returns with stock restoration and refund accounting
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

Financial mutations are performed through PostgreSQL RPCs. Direct client writes to the protected financial tables are restricted. Store and role checks are enforced in the database rather than relying only on hidden Flutter screens.

## Repository structure

```text
lib/
  core/
  features/
supabase/
  migrations/
  seed.sql
test/
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

`supabase db push` must apply **all** files under `supabase/migrations/` in order. Running only `001_init.sql` is not sufficient for the current application.

After the migrations:

1. Review Supabase Database Advisors.
2. Confirm Row Level Security is enabled.
3. Confirm anonymous users cannot execute protected business RPCs.
4. Enable leaked-password protection in Supabase Authentication settings.
5. Create or register the initial owner through the application.
6. Use store invitations for managers and sellers.
7. Test backup and restore before using real transaction data.

Do not place a Supabase `service_role` key in Flutter, GitHub source, APK build arguments, or user documentation.

## Flutter setup

Requirements:

- Flutter 3.44.1
- Dart version bundled with Flutter 3.44.1
- Java 17
- Android SDK/compile SDK 36

```bash
flutter pub get
flutter analyze --no-fatal-infos
flutter test
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
- Refund and expense entries in the financial ledger
- Server-side net revenue and profit reporting
- Cash closing based on all recorded inflows and outflows assigned to the user

## GitHub quality gate

`.github/workflows/validate.yml` runs on pull requests and performs:

```text
flutter pub get
flutter analyze --no-fatal-infos
flutter test --coverage
```

Analyzer, test, and coverage diagnostics are uploaded even when validation fails.

## APK artifacts

`.github/workflows/build-apk.yml` creates an **unsigned validation APK** after analysis and tests.

Artifact name:

```text
dukaan-dhisme-pos-unsigned-validation-apk
```

The artifact contains a `BUILD_CHANNEL.txt` warning and is not a signed production release. It is intended for controlled installation testing only.

A production-distribution workflow must:

- Require all signing credentials
- Fail when signing credentials are missing
- Verify the signing certificate
- Protect the keystore outside the repository
- Use an incremented version code
- Produce a clearly named signed production artifact

## Manual release checklist

Before installing a candidate APK for real store testing:

1. Pull-request validation is green.
2. All migrations are committed and applied to staging.
3. Database security advisor has no anonymous privileged-RPC warnings.
4. Customer and supplier aggregate balances equal invoice/purchase balances.
5. Sale, payment, return, expense, purchase, and closing scenarios pass.
6. Backup and restore have been tested.
7. The production APK is signed with the store-owned release key.
8. The certificate fingerprint and version code are recorded.

## Current release status

The project has undergone substantial Red Team remediation. Core financial integrity and anonymous RPC exposure have been addressed in the remediation branch and live database, but unrestricted production deployment still requires:

- Successful merge of the validated remediation pull request
- Fresh staging-database reconstruction from committed migrations
- End-to-end manual transaction testing
- Leaked-password protection enabled
- Tested backup/restore procedures
- A signed production release workflow and release key
- Crash/error monitoring and operational alerting

Until those conditions are met, use only a controlled pilot with reconciliation and backups.

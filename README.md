# Dhisme POS — Flutter + Supabase Construction Materials Store App

Dhisme POS is a starter MVP for construction-materials store owners who are not always at the store. It gives the **Owner** remote monitoring/control and lets the **Seller Employee** create daily sales, request approvals, and submit cash closings.

## What is included

- Flutter Android app source code
- Supabase PostgreSQL schema
- RLS policies
- Atomic PostgreSQL RPC functions for sale creation, credit-sale approval, and daily cash closing
- Owner dashboard
- Seller dashboard
- Product management
- Customer/debt management
- Seller POS screen
- Owner approval workflow
- Daily cash closing
- Audit logs
- Setup and APK build instructions

## Architecture

```text
Flutter Android App
  ├── Owner Mode
  └── Seller Mode
        ↓
Supabase Auth + PostgreSQL + RLS + Realtime-ready tables
```

## Tech stack

- Flutter
- Supabase Auth
- Supabase PostgreSQL
- Supabase RPC functions
- Riverpod-ready project structure, though the starter uses simple stateful screens for easier continuation
- PDF package included for receipt generation later

## Folder structure

```text
lib/
  main.dart
  app.dart
  core/
  features/
    auth/
    dashboard/
    products/
    customers/
    sales/
    approvals/
    cash_closing/
    settings/
supabase/
  migrations/
  seed.sql
```

## Supabase setup

1. Create a Supabase project.
2. Open **SQL Editor**.
3. Run `supabase/migrations/001_init.sql`.
4. Run `supabase/seed.sql` after editing the sample user IDs.
5. In Supabase Auth, create users for the owner and sellers.
6. Insert matching rows in `profiles` with the user UUIDs.

## Important first-run data setup

The app expects each authenticated user to have a row in `profiles`.

Example:

```sql
insert into stores (id, name, phone, address)
values ('00000000-0000-0000-0000-000000000001', 'Dhisme Materials Store', '+251900000000', 'Jigjiga');

insert into profiles (id, store_id, full_name, phone, role)
values ('AUTH_USER_UUID_HERE', '00000000-0000-0000-0000-000000000001', 'Store Owner', '+251900000000', 'owner');
```

For a seller:

```sql
insert into profiles (id, store_id, full_name, phone, role)
values ('SELLER_AUTH_USER_UUID_HERE', '00000000-0000-0000-0000-000000000001', 'Ahmed Seller', '+251911111111', 'seller');
```

## Flutter setup

1. Install Flutter and Android Studio.
2. Open this folder in VS Code or Android Studio.
3. Run:

```bash
flutter pub get
```

4. Run the app with your Supabase keys:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
```

## Build APK

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
```

APK output:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## MVP workflow

### Seller cash sale

1. Seller logs in.
2. Opens POS.
3. Adds products to cart.
4. Selects cash/bank/mobile money.
5. App calls `create_cash_sale()`.
6. Backend validates stock, creates invoice, creates payment, reduces stock, logs stock movement, writes audit log.

### Seller credit sale

1. Seller selects customer.
2. Adds products to cart.
3. Chooses **Credit request**.
4. App calls `request_credit_sale()`.
5. Owner sees pending request.
6. Owner approves via `decide_approval_request()`.
7. Backend validates stock, completes sale, reduces stock, and increases customer debt.

### Daily cash closing

1. Seller submits actual cash.
2. Backend calculates expected cash from today's cash payments.
3. Difference is saved.
4. Owner reviews cash closing.

## Security model

- All tables have RLS enabled.
- Users can only access their own store data.
- Sellers cannot insert/edit products.
- Sellers create sales only through secure RPC functions.
- Sellers cannot directly approve restricted actions.
- Owner-only approval is enforced in database functions.

## What to build next

1. PDF receipt screen with printable/shareable invoice.
2. Supplier purchases and stock-in module.
3. Barcode/QR scanning.
4. Realtime notifications.
5. Offline local storage and sync queue.
6. Employee invitation flow using Supabase Edge Functions.
7. Delivery assignment and confirmation.

## Notes

This is a strong MVP starter, not a final audited production system. Before using with real money, test thoroughly with real store scenarios and confirm RLS policies, database functions, and backup procedures.

---

## Automatic GitHub APK build

This package includes:

```text
.github/workflows/build-apk.yml
```

Upload the project to GitHub, add repository secrets:

```text
SUPABASE_URL
SUPABASE_ANON_KEY
```

Then run:

```text
Actions → Build Dhisme POS Android APK → Run workflow
```

Download APK from the workflow artifact:

```text
dhisme-pos-debug-apk
```

See:

```text
docs/GITHUB_APK_BUILD_STEPS.md
```

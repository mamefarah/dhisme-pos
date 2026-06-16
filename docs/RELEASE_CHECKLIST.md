# Dhisme POS — Release Checklist

Run through this list before handing the APK to the pilot store.

---

## 1. Database Migrations

Apply every migration in order from the Supabase Dashboard → SQL Editor:

- [ ] `001_init.sql` — base tables, RLS, core RPCs
- [ ] `20260614000000_phase2_owner_signup.sql` — register_owner RPC
- [ ] `20260614120000_phase3_employee_management.sql` — manager/seller roles, invites
- [ ] `20260614180000_phase4_role_based_access.sql` — manager permissions
- [ ] `20260614200000_phase5_suppliers.sql` — suppliers table
- [ ] `20260614220000_phase6_purchases.sql` — purchases + stock-in RPC
- [ ] `20260615000000_phase7_inventory.sql` — adjust_stock RPC
- [ ] `20260615020000_phase8_customer_payments.sql` — debt payments
- [ ] `20260616010000_015_security_hardening.sql` — revoke anon, grant RPCs
- [ ] `20260616020000_016_performance_indexes.sql` — FK indexes
- [ ] `20260616030000_017_rls_sales_restriction.sql` — sellers see only own sales
- [ ] `20260616040000_018_profit_and_payment_method.sql` — payment_method + cost tracking
- [ ] `20260616050000_019_customer_credit_controls.sql` — credit limits

## 2. Supabase Project Settings

- [ ] Email confirmation disabled (Authentication → Settings → Enable email confirmations → OFF)
      so owners can register immediately without waiting for an email.
- [ ] Site URL and redirect URL set correctly if email confirmation is enabled.
- [ ] RLS is enabled on every table (verify in Table Editor → each table → RLS).
- [ ] `SUPABASE_URL` and `SUPABASE_ANON_KEY` secrets added to GitHub repository
      (Settings → Secrets and variables → Actions).

## 3. Build

- [ ] GitHub Actions workflow ran successfully on `main` branch.
- [ ] APK artifact `dhisme-pos-release-apk` downloaded from the Actions run.
- [ ] APK installs on a real Android device (Android 8+ recommended).
- [ ] App opens without crash on first launch.

## 4. Owner Onboarding

- [ ] Owner creates a Supabase Auth account (email + password) in Supabase Dashboard
      OR via the in-app Register screen.
- [ ] After first login, owner completes registration (store name, phone, address).
- [ ] Owner profile row visible in `profiles` table with `role = 'owner'`.
- [ ] `current_user_store_id()` returns the correct store UUID for the owner.

## 5. Employee Setup

- [ ] Owner creates an invite code (Settings → Manage Employees → Add Employee).
- [ ] Employee creates a Supabase Auth account.
- [ ] Employee uses the invite code in the Register screen.
- [ ] Employee profile appears in Manage Employees with correct role (seller/manager).

## 6. Core Feature Smoke Test

Run the PILOT_TEST_SCRIPT.md for a full walk-through. Quick check:

- [ ] Products: add, edit, set buying price, set selling price, set minimum stock.
- [ ] Cash sale: select product, choose payment method (cash/bank/mobile money), complete.
- [ ] Credit sale: select customer, submit, owner approves, stock is decremented.
- [ ] Customer payment: record payment, balance reduces.
- [ ] Daily cash closing: seller submits, owner reviews.
- [ ] Sales Reports: revenue totals match manual count.
- [ ] Gross Profit card appears after at least one sale with a product that has a buying price set.

## 7. Security Spot-Check

- [ ] Unauthenticated PostgREST request to `/rest/v1/sales` returns 0 rows (RLS blocks it).
- [ ] Seller cannot see other sellers' sales in the history screen.
- [ ] Seller cannot access the approvals or reports screens (UI gates).
- [ ] Anon key is NOT visible anywhere in the Flutter source files.

## 8. Known Limitations (for pilot)

- Offline mode is not implemented. The app requires an internet connection.
- PDF receipts are generated on-device; sharing requires a compatible app (email, WhatsApp).
- No push notifications; owners must manually refresh the approvals screen.
- Gross Profit card only appears when product buying prices have been entered.

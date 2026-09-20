# Dhisme POS — Claude Working Rules

Flutter + Supabase Android POS app for construction materials stores.
Targets non-technical store owners and sellers. Keep everything simple and mobile-first.

---

## 1. Secrets & Security — Hard Rules

- **Never hardcode** Supabase URL, anon key, service role key, JWT secret, database password, or any credential anywhere in the Flutter source, pubspec, or any config file committed to the repository.
- The Flutter app must only use the **anon key** injected at build time via:
  ```
  --dart-define=SUPABASE_URL=...
  --dart-define=SUPABASE_ANON_KEY=...
  ```
- The **service_role key**, **JWT secret**, and **database password** must never appear in mobile app code. They belong only in server-side scripts or Supabase dashboard — never in a Flutter build.
- GitHub Actions reads these from repository secrets: `SUPABASE_URL` and `SUPABASE_ANON_KEY`. Do not change their names or inject them any other way.
- Never print, log, or expose secret values anywhere in the codebase.

---

## 2. Database Changes — Migration-First Workflow

Before touching any table, column, index, RLS policy, function, or trigger:

1. Write a plain SQL migration file (e.g. `supabase/migrations/YYYYMMDDHHMMSS_description.sql`).
2. Explain exactly what the migration does and how to run it:
   - Via Supabase CLI: `supabase db push` (preferred when CLI is set up).
   - Via Supabase Dashboard: open **SQL Editor**, paste the migration, click **Run**.
3. Get explicit approval before running any migration against the production database.
4. **Never drop, truncate, delete, or reset production data** without a clear, explicit instruction from the user. When in doubt, ask first.
5. All new tables must have appropriate RLS policies. State them in the migration.

---

## 3. GitHub Actions — Keep the APK Build Working

There are two separate Android workflows. Do not conflate them.

### `.github/workflows/build-apk.yml` — validation build
- Runs on push to `main`/`master` and on `workflow_dispatch`.
- Runs `flutter analyze --fatal-infos` and `flutter test --coverage` before building — the build fails if either fails.
- Builds with `flutter build apk --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`. This is a **release-mode build with debug signing** (the default Flutter debug keystore), not a `--debug` build — it exists to validate that the app builds and runs, not to distribute a production release.
- Writes `BUILD_CHANNEL.txt` (`NON-PRODUCTION VALIDATION BUILD / RELEASE MODE / DEBUG SIGNING / NOT FOR PRODUCTION DISTRIBUTION`) and a `SHA256SUMS` file alongside the APK.
- The artifact (`dukaan-dhisme-pos-validation-apk`, containing `app-release.apk`, `BUILD_CHANNEL.txt`, `SHA256SUMS`) is uploaded **only when the run was triggered by `workflow_dispatch`** — a plain push to `main` still analyzes/tests/builds but does not upload anything. Retention is 1 day.
- Never remove the `--dart-define` flags, rename the secrets, or change the artifact upload step without testing the full build first.
- The app icon is generated via `dart run flutter_launcher_icons` from `assets/icon/app_icon.png`. Keep this step in the workflow.
- If you change `pubspec.yaml` (add/remove packages), verify `flutter pub get` still resolves cleanly.

### `.github/workflows/production-release.yml` — signed production release
- Manual `workflow_dispatch` only — never runs on push.
- Requires protected repository secrets: `ANDROID_KEYSTORE_BASE64`, `ANDROID_STORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` (plus `SUPABASE_URL`/`SUPABASE_ANON_KEY`), and fails fast if any are missing.
- Builds a signed production **AAB** (`flutter build appbundle --release`) and **APK** (`flutter build apk --release`), then verifies the AAB/APK are actually signed with the protected release key (`jarsigner`/`apksigner`) and explicitly fails if the APK carries the Android debug certificate.
- Uploads `dukaan-dhisme-pos-signed-production-release` (AAB, APK, `RELEASE_METADATA.txt`, `SHA256SUMS`), retention 1 day.
- Only trigger this workflow for an actual production release, with explicit authorization — never as a way to "test" a build. Use `build-apk.yml` for validation.

---

## 4. Architecture & Code Style

### Project layout
```
lib/
  core/
    services/       # supabase_service.dart (global sb client)
    theme/          # app_theme.dart (navy + orange, Material 3)
    utils/          # money.dart, dates.dart
    widgets/        # shared reusable widgets
  features/
    auth/           # models, data, screens
    dashboard/      # owner/manager/seller home screens + stats
    products/       # inventory CRUD
    customers/      # customer + debt management
    sales/          # POS screen, receipt
    approvals/      # owner approval workflow
    cash_closing/   # daily cash close submit + review
    settings/       # profile, logout
```

### Patterns to follow
- Feature-first folder structure. One feature per folder.
- Repository pattern for all Supabase access. Screens never call `sb` directly.
- Complex or multi-step operations use Supabase **RPC functions** (stored procedures) for atomicity.
- State management: plain `StatefulWidget` + `setState`. Riverpod is installed but not yet wired — don't add it without discussion.
- Navigation: `MaterialPageRoute` push/pop. go_router is installed for future use — don't switch to it without discussion.
- No comments that describe *what* the code does. Only add a comment when the *why* is non-obvious.
- No over-engineering. No abstractions for hypothetical future requirements.

### Do not add
- Hardcoded sample/test data left in production code.
- Feature flags, backwards-compat shims, or dead code.
- New packages without checking if existing ones already cover the need.

---

## 5. UI & UX — Mobile-First, Non-Technical Users

- **Target users**: store owners and sellers who are not software-literate. Every screen must be self-explanatory.
- **Theme**: navy `#0B1F3A` primary, orange `#F58220` accent, light background `#F5F6FA`. Do not change brand colors without approval.
- All text, labels, and error messages must be written in plain, friendly language. No technical jargon visible to users.
- Error messages must explain what went wrong **and** what the user should do next.
- Loading states must always show a `CircularProgressIndicator`. Never leave a blank screen during async work.
- Forms must validate inputs client-side before any network call.

### Manual UI review (Impeccable style)
The `/plugin` slash command is not available in the user's phone Claude Code environment.  
For any UI change, perform a manual Impeccable-style review covering:
- Layout correctness on small screens (360dp width).
- Tap target sizes (minimum 48×48dp).
- Correct use of theme colors and text styles.
- Accessibility: meaningful icon labels, sufficient contrast.
- Edge cases: empty lists, long names, zero/negative values, loading, error states.

---

## 6. Auth, Roles & RLS — Review Carefully

### Auth flow
- Supabase Auth (email + password). No OAuth, no magic link, unless explicitly requested.
- `AuthGate` listens to `onAuthStateChange` and routes to `OwnerHomeScreen`, `ManagerHomeScreen`, or `SellerHomeScreen` based on `profile.role`.
- Managers and sellers join via the owner-generated invite-code flow (`create_store_invite`/`register_with_invite` RPCs, `lib/features/employees/`), not manual Dashboard creation. **`create_store_invite` is owner-only to call, full stop** — managers cannot invite anyone, of any role. This is the normal onboarding path for every manager/seller account.
- A manually SQL-provisioned `profiles` row (no invite, no self-registration) is an **explicit administrative exception**, used only for a specifically authorized, permanent internal test account — never the normal lifecycle, and never done via `auth.users` SQL inserts (Supabase Auth still creates the login; only the matching `profiles` row may be inserted this way, guarded by explicit precondition checks and only after explicit approval).

### Profiles table
- Every authenticated user must have exactly one row in `profiles` (`id` matches `auth.users.id`).
- Fields: `id`, `store_id`, `full_name`, `role` (`owner` | `manager` | `seller`), `phone`.
- Missing profile → show `_ProfileMissingScreen` with the user's UUID so the owner can fix it.

### RLS
- All tables must have RLS enabled with policies scoped to `store_id`.
- **Owner**: full read/write in their store, including store identity (`stores.name`/`phone`/`address` — owner-only `UPDATE` policy on `stores`), employee/invite administration (`create_store_invite`), approval decisions (`decide_approval_request`), and cash-closing review (`review_daily_cash_closing`).
- **Manager**: near-owner operational access — store-wide read on financial/operational tables, insert/update on products/categories/suppliers, update on customers, purchases, expenses, stock adjustments/reconciliation, and the owner/manager-gated reporting RPCs (`sales_summary_v2`, `profit_summary_v2`, `financial_summary_v2`, `top_products_v2`). Managers **cannot** change store identity (no `stores` UPDATE policy for manager — enforced at the database, not just hidden in the UI), decide approval requests, review cash closings, or issue invites — all four are owner-only both in the backend and in the UI.
- **Seller**: read products/customers, create sales and cash closings, request credit sales (goes to owner approval); cannot see other sellers' data, cannot access the reporting RPCs above (owner/manager only), cannot approve or review anything.
- `create_cash_sale_v2` and `request_credit_sale_v2` are **not role-agnostic** — they explicitly permit `owner`/`manager`/`seller` but enforce role-specific discount ceilings inside the function body (seller ≤2%, manager ≤5%; no cap enforced for owner). Don't describe these as open to any role without qualification.
- Products have no `DELETE` path for any normal application role (owner, manager, or seller) — RLS and grants only cover `SELECT`/`INSERT`/`UPDATE`, and `current_stock` is excluded from the UPDATE column grant so it can only change via `adjust_stock`/`create_cash_sale_v2`/`record_return` (see the domain table below). This says nothing about database/service-role administrative capability, which is outside RLS entirely.
- When adding a new table, always state the RLS policies and include them in the migration.

---

## 7. Domain Areas — Careful Review Required

Each area below is sensitive. When implementing changes here, reason through the full impact before writing code.

| Area | Key considerations |
|---|---|
| **Inventory / Products** | Stock levels change on sale. `create_cash_sale_v2` RPC must decrement stock atomically. Never update stock outside an RPC without approval. No role (including owner) has a product `DELETE` path — only `SELECT`/`INSERT`/`UPDATE` are granted, and `current_stock` is excluded from the UPDATE grant. |
| **Suppliers & Purchases** | Implemented (`lib/features/suppliers/`, `lib/features/purchases/`), manager-accessible in both UI and RLS. Purchases increment stock via RPC, consistent with the rest of the stock-mutation model. |
| **Sales (POS)** | Cash, bank, mobile money = immediate (`create_cash_sale_v2`). Credit = approval request (`request_credit_sale_v2`). Payment method affects daily cash closing reconciliation. Owner/manager/seller can all create sales, but discount % is capped per role inside the RPC (seller ≤2%, manager ≤5%). |
| **Customer Debt** | `total_balance` on `customers` is derived from credit sales minus payments. Never modify it directly — use RPCs. |
| **Approvals** | Owner-only, both backend and UI. `decide_approval_request` RPC checks role before it even looks up the request. Status: pending → approved / rejected. No going back once decided. |
| **Cash Closing** | Seller/manager/owner submits actual cash (`submit_daily_cash_closing_v2`) → owner reviews (`review_daily_cash_closing`, owner-only). One closing per seller per day. |
| **Store Settings** | Store identity (name/phone/address) is owner-only: `stores` has an explicit owner-scoped `UPDATE` RLS policy (migration `037_owner_store_settings_update_policy`), and the Store Settings screen is hidden from manager/seller in the UI. `StoreRepository.updateStore()` treats a zero-row update result as a failure, not a success. |
| **Reports / Dashboard** | `dashboard_stats_v2` (via `dashboard_stats`) returns aggregated figures, scoped to "own" for sellers and "store" for owner/manager. `sales_summary_v2`, `profit_summary_v2`, `financial_summary_v2`, `top_products_v2` are owner/manager only (sellers denied) and are exposed to manager in the Settings → Sales Reports UI. If schema changes, update the RPCs to match. |

---

## 8. Response Mode

- **Default**: detailed mode. Explain what you're doing, why, and what the user should verify.
- **Short summary mode**: only when the user explicitly asks for a brief response.
- For audits and implementation planning: use detailed mode with step-by-step reasoning.
- After every code change: state exactly what changed, what was not changed, and what the user should test.

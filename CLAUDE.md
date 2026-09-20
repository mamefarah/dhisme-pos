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

- The workflow file is `.github/workflows/build-apk.yml`.
- It builds a debug APK on push to `main`/`master` and on `workflow_dispatch`.
- It uses `flutter build apk --debug --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`.
- Never remove the `--dart-define` flags, rename the secrets, or change the artifact upload step without testing the full build first.
- The app icon is generated via `dart run flutter_launcher_icons` from `assets/icon/app_icon.png`. Keep this step in the workflow.
- If you change `pubspec.yaml` (add/remove packages), verify `flutter pub get` still resolves cleanly.

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
- Managers and sellers join via the owner-generated invite-code flow (`create_store_invite`/`register_with_invite` RPCs, `lib/features/employees/`), not manual Dashboard creation.

### Profiles table
- Every authenticated user must have exactly one row in `profiles` (`id` matches `auth.users.id`).
- Fields: `id`, `store_id`, `full_name`, `role` (`owner` | `manager` | `seller`), `phone`.
- Missing profile → show `_ProfileMissingScreen` with the user's UUID so the owner can fix it.

### RLS
- All tables must have RLS enabled with policies scoped to `store_id`.
- Owners can read/write everything in their store.
- Managers have near-owner-level access: store-wide read on financial/operational tables, insert/update on products/categories/suppliers, update on customers, and most v2 RPCs — but cannot decide approval requests, review cash closings, or issue invites (owner-only).
- Sellers can read products, customers; create sales and cash closings; cannot approve or see other sellers' data.
- When adding a new table, always state the RLS policies and include them in the migration.

---

## 7. Domain Areas — Careful Review Required

Each area below is sensitive. When implementing changes here, reason through the full impact before writing code.

| Area | Key considerations |
|---|---|
| **Inventory / Products** | Stock levels change on sale. `create_cash_sale` RPC must decrement stock atomically. Never update stock outside an RPC without approval. |
| **Suppliers & Purchases** | Not yet implemented. If added, purchases must increment stock via RPC. |
| **Sales (POS)** | Cash, bank, mobile money = immediate. Credit = approval request. Payment method affects daily cash closing reconciliation. |
| **Customer Debt** | `total_balance` on `customers` is derived from credit sales minus payments. Never modify it directly — use RPCs. |
| **Approvals** | Owner-only. `decide_approval_request` RPC. Status: pending → approved / rejected. No going back once decided. |
| **Cash Closing** | Seller submits actual cash → owner reviews. `submit_daily_cash_closing` and `review_daily_cash_closing` RPCs. One closing per seller per day. |
| **Reports / Dashboard** | `dashboard_stats` RPC returns aggregated figures. If schema changes, update the RPC to match. |

---

## 8. Response Mode

- **Default**: detailed mode. Explain what you're doing, why, and what the user should verify.
- **Short summary mode**: only when the user explicitly asks for a brief response.
- For audits and implementation planning: use detailed mode with step-by-step reasoning.
- After every code change: state exactly what changed, what was not changed, and what the user should test.

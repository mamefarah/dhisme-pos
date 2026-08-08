#!/usr/bin/env bash
set -euo pipefail

command -v supabase >/dev/null 2>&1
command -v psql >/dev/null 2>&1
command -v openssl >/dev/null 2>&1
command -v sha256sum >/dev/null 2>&1

: "${RUNNER_TEMP:?RUNNER_TEMP is required for the isolated restore drill}"

eval "$(supabase status -o env | grep '^DB_URL=')"
test -n "${DB_URL:-}"
SOURCE_DB_URL="$DB_URL"

# This application currently defines no custom Postgres roles. A future custom
# role requires an explicit restore policy/password procedure rather than
# silently treating it as a Supabase-managed role.
CUSTOM_ROLES="$(psql "$SOURCE_DB_URL" -X -A -t -c "
  select string_agg(rolname, ',')
  from pg_roles
  where rolname !~ '^pg_'
    and rolname !~ '^supabase_'
    and rolname not in (
      'postgres','anon','authenticated','authenticator','service_role',
      'dashboard_user','pgbouncer','cli_login_postgres'
    );
")"
if [ -n "$CUSTOM_ROLES" ]; then
  echo "Unsupported custom database roles detected for automated restore: $CUSTOM_ROLES" >&2
  exit 1
fi

# Seed a coherent business fixture through the real v2 transactional API.
psql "$SOURCE_DB_URL" --variable ON_ERROR_STOP=1 \
  --file scripts/restore_drill_fixture.sql

MANIFEST_SQL="$RUNNER_TEMP/restore-manifest.sql"
cat > "$MANIFEST_SQL" <<'SQL'
select jsonb_build_object(
  'auth_users', (select count(*) from auth.users where id='91111111-1111-4111-8111-111111111111'::uuid),
  'stores', (select count(*) from public.stores where id='90000000-0000-0000-0000-000000000001'::uuid),
  'profiles', (select count(*) from public.profiles where store_id='90000000-0000-0000-0000-000000000001'::uuid),
  'categories', (select count(*) from public.categories where store_id='90000000-0000-0000-0000-000000000001'::uuid),
  'products', (select count(*) from public.products where store_id='90000000-0000-0000-0000-000000000001'::uuid),
  'customers', (select count(*) from public.customers where store_id='90000000-0000-0000-0000-000000000001'::uuid),
  'suppliers', (select count(*) from public.suppliers where store_id='90000000-0000-0000-0000-000000000001'::uuid),
  'purchases', (select count(*) from public.purchases where store_id='90000000-0000-0000-0000-000000000001'::uuid),
  'purchase_items', (select count(*) from public.purchase_items where store_id='90000000-0000-0000-0000-000000000001'::uuid),
  'sales', (select count(*) from public.sales where store_id='90000000-0000-0000-0000-000000000001'::uuid),
  'sale_items', (select count(*) from public.sale_items where store_id='90000000-0000-0000-0000-000000000001'::uuid),
  'payments', (select count(*) from public.payments where store_id='90000000-0000-0000-0000-000000000001'::uuid),
  'customer_payments', (select count(*) from public.customer_payments where store_id='90000000-0000-0000-0000-000000000001'::uuid),
  'supplier_payments', (select count(*) from public.supplier_payments where store_id='90000000-0000-0000-0000-000000000001'::uuid),
  'customer_allocations', (select count(*) from public.customer_payment_allocations where store_id='90000000-0000-0000-0000-000000000001'::uuid),
  'supplier_allocations', (select count(*) from public.supplier_payment_allocations where store_id='90000000-0000-0000-0000-000000000001'::uuid),
  'returns', (select count(*) from public.returns where store_id='90000000-0000-0000-0000-000000000001'::uuid),
  'return_items', (select count(*) from public.return_items where store_id='90000000-0000-0000-0000-000000000001'::uuid),
  'expenses', (select count(*) from public.expenses where store_id='90000000-0000-0000-0000-000000000001'::uuid),
  'cash_ledger', (select count(*) from public.cash_ledger where store_id='90000000-0000-0000-0000-000000000001'::uuid),
  'cash_adjustments', (select count(*) from public.cash_adjustments where store_id='90000000-0000-0000-0000-000000000001'::uuid),
  'closings', (select count(*) from public.daily_cash_closings where store_id='90000000-0000-0000-0000-000000000001'::uuid),
  'approvals', (select count(*) from public.approval_requests where store_id='90000000-0000-0000-0000-000000000001'::uuid),
  'idempotency', (select count(*) from public.operation_idempotency where store_id='90000000-0000-0000-0000-000000000001'::uuid),
  'product_stock', (select current_stock from public.products where id='93333333-3333-4333-8333-333333333333'::uuid),
  'customer_balance', (select total_balance from public.customers where id='94444444-4444-4444-8444-444444444444'::uuid),
  'supplier_balance', (select total_balance from public.suppliers where id='95555555-5555-4555-8555-555555555555'::uuid)
)::text;
SQL

psql "$SOURCE_DB_URL" -X -A -t --file "$MANIFEST_SQL" > "$RUNNER_TEMP/source-manifest.txt"
test -s "$RUNNER_TEMP/source-manifest.txt"

export SUPABASE_DB_URL="$SOURCE_DB_URL"
export BACKUP_ENCRYPTION_PASSPHRASE="ci-only-backup-roundtrip-secret"
export BACKUP_DIR="$RUNNER_TEMP/dhisme-backup-test"

bash scripts/backup_supabase.sh
BACKUP_FILE="$(find "$BACKUP_DIR" -maxdepth 1 -name '*.tar.gz.enc' -type f | head -n 1)"
test -n "$BACKUP_FILE"
bash scripts/verify_supabase_backup.sh "$BACKUP_FILE"

RESTORE_WORK="$RUNNER_TEMP/restore-work"
mkdir -p "$RESTORE_WORK"
openssl enc -d -aes-256-cbc -pbkdf2 \
  -in "$BACKUP_FILE" \
  -out "$RESTORE_WORK/backup.tar.gz" \
  -pass env:BACKUP_ENCRYPTION_PASSPHRASE
tar -xzf "$RESTORE_WORK/backup.tar.gz" -C "$RESTORE_WORK"
(cd "$RESTORE_WORK" && sha256sum -c SHA256SUMS)

RESTORE_STARTED="$(date +%s)"
supabase stop --no-backup

MIGRATIONS_HOLD="$RUNNER_TEMP/migrations-hold"
mv supabase/migrations "$MIGRATIONS_HOLD"
mkdir -p supabase/migrations
if [ -f supabase/seed.sql ]; then
  mv supabase/seed.sql "$RUNNER_TEMP/seed.sql.hold"
fi

restore_repo_paths() {
  if [ -d "$MIGRATIONS_HOLD" ]; then
    rm -rf supabase/migrations
    mv "$MIGRATIONS_HOLD" supabase/migrations
  fi
  if [ -f "$RUNNER_TEMP/seed.sql.hold" ]; then
    mv "$RUNNER_TEMP/seed.sql.hold" supabase/seed.sql
  fi
}
trap restore_repo_paths EXIT

# Clean Supabase target: managed schemas/roles exist, app migrations/seed do not run.
supabase db start
eval "$(supabase status -o env | grep '^DB_URL=')"
test -n "${DB_URL:-}"
TARGET_DB_URL="$DB_URL"

CLEAN_CHECK="$(psql "$TARGET_DB_URL" -X -A -t -c "select to_regclass('public.stores') is null")"
test "$CLEAN_CHECK" = "t"

for required_role in anon authenticated authenticator service_role; do
  ROLE_EXISTS="$(psql "$TARGET_DB_URL" -X -A -t -c "select exists(select 1 from pg_roles where rolname='$required_role')")"
  test "$ROLE_EXISTS" = "t"
done

# The encrypted archive retains roles.sql for inspection/recovery. For this
# project, however, every DB role is Supabase-managed; a fresh Supabase target
# must retain its own managed role attributes/settings. This avoids transplanting
# non-portable ALTER ROLE settings such as log_min_messages. If custom app roles
# are introduced later, the source check above makes this drill fail closed.
#
# Supabase CLI also documents resetting target default table privileges before
# schema restore so the dump's explicit privileges remain authoritative.
psql "$TARGET_DB_URL" --variable ON_ERROR_STOP=1 <<'SQL'
alter default privileges in schema public revoke all on tables from anon, authenticated;
SQL

psql "$TARGET_DB_URL" \
  --single-transaction \
  --variable ON_ERROR_STOP=1 \
  --file "$RESTORE_WORK/schema.sql" \
  --command 'SET session_replication_role = replica' \
  --file "$RESTORE_WORK/data.sql"

psql "$TARGET_DB_URL" \
  --single-transaction \
  --variable ON_ERROR_STOP=1 \
  --file "$RESTORE_WORK/history_schema.sql" \
  --file "$RESTORE_WORK/history_data.sql"

psql "$TARGET_DB_URL" -X -A -t --file "$MANIFEST_SQL" > "$RUNNER_TEMP/target-manifest.txt"
diff -u "$RUNNER_TEMP/source-manifest.txt" "$RUNNER_TEMP/target-manifest.txt"

restore_repo_paths
trap - EXIT

# Run the same security/RLS regression suite against the restored database.
supabase test db --local

psql "$TARGET_DB_URL" --variable ON_ERROR_STOP=1 <<'SQL'
do $$
begin
  if has_column_privilege('authenticated', 'public.customers', 'total_balance', 'INSERT')
     or has_column_privilege('authenticated', 'public.customers', 'total_balance', 'UPDATE') then
    raise exception 'Restored customers.total_balance privileges are unsafe';
  end if;
  if has_column_privilege('authenticated', 'public.suppliers', 'total_balance', 'INSERT')
     or has_column_privilege('authenticated', 'public.suppliers', 'total_balance', 'UPDATE') then
    raise exception 'Restored suppliers.total_balance privileges are unsafe';
  end if;
  if not (select relrowsecurity from pg_class where oid='public.customers'::regclass)
     or not (select relrowsecurity from pg_class where oid='public.suppliers'::regclass) then
    raise exception 'RLS was not preserved by restore';
  end if;
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='record_purchase_v2' and p.prosecdef
  ) then
    raise exception 'record_purchase_v2 SECURITY DEFINER contract missing after restore';
  end if;
  if has_function_privilege('anon','public.new_return_no()','execute')
     or has_function_privilege('authenticated','public.new_return_no()','execute') then
    raise exception 'Internal return-number helper became directly executable after restore';
  end if;
end $$;
SQL

RESTORE_FINISHED="$(date +%s)"
RESTORE_SECONDS="$((RESTORE_FINISHED - RESTORE_STARTED))"
echo "Restore drill completed in ${RESTORE_SECONDS} seconds."

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "### Supabase encrypted restore drill"
    echo "- Clean target verified before restore: yes"
    echo "- Supabase-managed target roles preserved: yes"
    echo "- Encrypted archive integrity: pass"
    echo "- Source/restore business manifest: exact match"
    echo "- Post-restore pgTAP security/RLS suite: pass"
    echo "- Migrations 028–032 recovery/security invariants: pass"
    echo "- Measured restore duration: ${RESTORE_SECONDS} seconds"
  } >> "$GITHUB_STEP_SUMMARY"
fi

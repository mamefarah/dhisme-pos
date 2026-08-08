# Dukaan Dhisme POS — Backup & Restore Runbook

## Purpose

This runbook defines the minimum recoverability process for the controlled pilot and future production rollout.

The connected Supabase organization is currently on the **Free plan**. Do not treat dashboard backup availability as the application's recovery strategy. Keep independent encrypted logical backups off-site.

## Verified recovery baseline — 08 Aug 2026

The repository now performs an end-to-end encrypted restore drill in isolated Supabase/Postgres CI:

- reconstruct the complete migration chain through migration 032;
- create a coherent transactional fixture through the real v2 purchase, sale, return, credit/payment, expense, cash-adjustment and cash-closing RPCs;
- create and encrypt a logical backup;
- verify all archive checksums;
- destroy the source database;
- initialize a clean Supabase target with no application migrations/data;
- restore schema, Auth/business data and migration history;
- require an exact source-versus-restored business manifest match;
- rerun the 30-test security/RLS suite against the restored database;
- recheck protected financial-balance privileges, RLS, SECURITY DEFINER contracts and internal-helper permissions.

The verified drill completed in **37 seconds** on a GitHub-hosted isolated environment. Treat this as a technical baseline, **not** a guaranteed production outage RTO; a real hosted restore includes provisioning, connection, operator and application-reconfiguration time.

The recovery drill also exposed and corrected three repository/live-schema drift defects:

- migration 030 captures the `new_return_no()` helper required by `record_return_v2()`;
- migration 031 captures the working `record_expense_v2()` timestamp behavior;
- migration 032 captures the working `record_cash_adjustment_v2()` timestamp behavior.

## Pilot backup policy

During the controlled pilot:

- Create one encrypted logical backup **at the end of every operating day** and before any material database migration.
- Keep at least the latest 14 successful backup sets during the pilot.
- Store the encrypted backup in an off-site location separate from the computer used to run the POS.
- Store the encryption passphrase separately from the backup file.
- Never commit database dumps, passwords, connection strings, or encryption passphrases to Git.

For unrestricted production, review the Supabase plan and recovery requirements again. A financial POS should have a documented RPO/RTO and a tested recovery path appropriate to its transaction volume.

## Prerequisites

Install:

- Supabase CLI
- Docker (used by `supabase db dump`)
- PostgreSQL `psql`
- OpenSSL
- `sha256sum`

Obtain a Supabase **Session Pooler** or direct Postgres connection string with the database password. Do not use the public API key as a database connection credential, and do not paste the database password into chat, source control, issue comments or documentation.

## Create a backup

From the repository root:

```bash
export SUPABASE_DB_URL='postgresql://...'
export BACKUP_ENCRYPTION_PASSPHRASE='use-a-long-unique-secret'
bash scripts/backup_supabase.sh
```

The script creates:

- roles dump;
- schema dump;
- data dump, including Auth/business records handled by the Supabase CLI dump process;
- Supabase migration-history schema/data;
- internal SHA-256 checksums;
- backup metadata;
- one AES-256-CBC/PBKDF2 encrypted archive;
- an outer encrypted-file SHA-256 checksum.

Local output goes under `backups/`, which is ignored by Git.

## Verify every backup

A backup is not considered successful until integrity verification passes:

```bash
export BACKUP_ENCRYPTION_PASSPHRASE='same-secret-used-for-backup'
bash scripts/verify_supabase_backup.sh backups/dhisme-pos-YYYYMMDDTHHMMSSZ.tar.gz.enc
```

Expected result:

- encrypted-file checksum passes when the sidecar is present;
- archive decrypts successfully;
- required SQL components are present and non-empty;
- internal checksums pass;
- **no restore is performed** by the verification script.

Record the backup timestamp and verification result in the pilot operations log.

## Off-site storage

Use at least two protected locations for production-significant backups, for example:

1. an encrypted cloud-drive location with MFA; and
2. a separately protected local/external copy.

Do not store the passphrase in the same folder as the encrypted database archive.

## Restore drill — non-production only

A restore drill must use a disposable/non-production Supabase project or local Supabase environment. **Never use the live `dhisme-pos` project for a restore drill.**

### 1. Decrypt and extract

```bash
mkdir restore-work
openssl enc -d -aes-256-cbc -pbkdf2 \
  -in dhisme-pos-YYYYMMDDTHHMMSSZ.tar.gz.enc \
  -out restore-work/backup.tar.gz \
  -pass env:BACKUP_ENCRYPTION_PASSPHRASE

tar -xzf restore-work/backup.tar.gz -C restore-work
cd restore-work
sha256sum -c SHA256SUMS
```

### 2. Prepare the target

Before restoring:

- confirm the target is non-production;
- confirm Postgres/Supabase versions are compatible;
- enable required extensions;
- obtain the target database connection string;
- keep the target application disconnected until validation completes;
- confirm whether the source has any **custom application Postgres roles**.

The current Dhisme POS project has **no custom application database roles**; its roles are Supabase-managed. A new Supabase project already owns/configures those platform roles. The automated recovery drill therefore preserves `roles.sql` in the encrypted archive for audit/recovery purposes but keeps the target project's managed role attributes rather than transplanting non-portable settings such as platform logging parameters.

If custom roles are introduced later, stop and define their explicit restore/password procedure before considering recovery validated.

### 3. Reset target default privileges

Before restoring the application schema into a new Supabase target, make explicit table grants from the dump authoritative:

```sql
ALTER DEFAULT PRIVILEGES IN SCHEMA public
REVOKE ALL ON TABLES FROM anon, authenticated;
```

### 4. Restore schema and data

For the current project, where all database roles are Supabase-managed:

```bash
psql \
  --single-transaction \
  --variable ON_ERROR_STOP=1 \
  --file schema.sql \
  --command 'SET session_replication_role = replica' \
  --file data.sql \
  --dbname "$TARGET_DB_URL"
```

Do **not** globally disable error handling. If the project's role model changes, review `roles.sql` and Supabase's current restore documentation before restoring custom roles.

Then restore migration history for CLI parity:

```bash
psql \
  --single-transaction \
  --variable ON_ERROR_STOP=1 \
  --file history_schema.sql \
  --file history_data.sql \
  --dbname "$TARGET_DB_URL"
```

## Restore validation checklist

A restore drill passes only when all of the following are verified:

- Auth users required by the restored profiles are present;
- key table counts and financial state match the source backup expectations;
- stores, profiles, customers, products, suppliers, purchases, sales, payments, returns, expenses, adjustments, closings and ledgers are present as expected;
- RLS is enabled on tenant/business tables;
- migrations 028–032 recovery/security invariants remain intact;
- `customers.total_balance` and `suppliers.total_balance` remain client-protected;
- internal `new_return_no()` is not directly executable by API client roles;
- Owner/Manager/Seller role checks behave correctly;
- cross-store access is denied;
- critical SECURITY DEFINER v2 transaction RPCs remain present and functional;
- migration history is restored;
- no unexpected restore errors are ignored.

Document the date, backup timestamp, target environment, duration, failures, corrections, and final result.

## Recovery objectives for the pilot

Until a paid/managed recovery strategy is selected, use these conservative pilot targets:

- **RPO:** no more than one operating day, improved by taking additional backups before risky changes;
- **technical restore baseline:** 37 seconds in the verified isolated CI drill on 08 Aug 2026;
- **operational RTO:** not yet guaranteed. Measure the full hosted process—including project availability, connection, restore and application reconfiguration—during an operator-run hosted recovery exercise before assigning an SLA.

The first encrypted backup of the **live** project remains a separate operator gate because it requires the live database password on a secure machine. CI recovery validation is not a substitute for retaining current production backups.

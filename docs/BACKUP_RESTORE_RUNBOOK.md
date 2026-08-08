# Dukaan Dhisme POS — Backup & Restore Runbook

## Purpose

This runbook defines the minimum recoverability process for the controlled pilot and future production rollout.

The connected Supabase organization is currently on the **Free plan**. Do not treat dashboard backup availability as the application's recovery strategy. Keep independent encrypted logical backups off-site.

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
- OpenSSL
- `sha256sum`

Obtain a Supabase **Session Pooler** or direct Postgres connection string with the database password. Do not use the public API key as a database connection credential.

## Create a backup

From the repository root:

```bash
export SUPABASE_DB_URL='postgresql://...'
export BACKUP_ENCRYPTION_PASSPHRASE='use-a-long-unique-secret'
./scripts/backup_supabase.sh
```

The script creates:

- roles dump;
- schema dump;
- data dump;
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
./scripts/verify_supabase_backup.sh backups/dhisme-pos-YYYYMMDDTHHMMSSZ.tar.gz.enc
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
- enable any required extensions;
- obtain the target database connection string;
- keep the target application disconnected until validation completes.

### 3. Restore

Use `psql` with stop-on-error and a single transaction:

```bash
psql \
  --single-transaction \
  --variable ON_ERROR_STOP=1 \
  --file roles.sql \
  --file schema.sql \
  --command 'SET session_replication_role = replica' \
  --file data.sql \
  --dbname "$TARGET_DB_URL"
```

Then restore migration history if required for CLI parity:

```bash
psql \
  --single-transaction \
  --variable ON_ERROR_STOP=1 \
  --file history_schema.sql \
  --file history_data.sql \
  --dbname "$TARGET_DB_URL"
```

Supabase-managed roles can differ between environments. If a role/grant statement fails, stop and review the exact statement rather than disabling error handling globally.

## Restore validation checklist

A restore drill passes only when all of the following are verified:

- key table counts match the source backup expectations;
- stores, profiles, customers, products, sales, payments, purchases, returns, expenses, and ledgers are present as expected;
- RLS is enabled on tenant/business tables;
- migrations 028 and 029 invariants remain intact;
- `customers.total_balance` and `suppliers.total_balance` remain client-protected;
- Owner/Manager/Seller role checks behave correctly;
- cross-store access is denied;
- critical SECURITY DEFINER v2 transaction RPCs execute correctly in test transactions;
- no unexpected restore errors are ignored.

Document the date, backup timestamp, target environment, duration, failures, corrections, and final result.

## Recovery objectives for the pilot

Until a paid/managed recovery strategy is selected, use these conservative pilot targets:

- **RPO:** no more than one operating day, improved by taking additional backups before risky changes;
- **RTO:** recovery is manual and must be measured during the first restore drill rather than assumed.

After the drill, replace the RTO estimate with the measured recovery time.

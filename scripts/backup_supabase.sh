#!/usr/bin/env bash
set -euo pipefail

# Logical backup for Supabase Free-plan projects.
# Required environment variables:
#   SUPABASE_DB_URL                 Session-pooler or direct Postgres connection string.
#   BACKUP_ENCRYPTION_PASSPHRASE   Strong passphrase used only for local AES-256 encryption.
# Optional:
#   BACKUP_DIR                     Output directory (default: ./backups).

: "${SUPABASE_DB_URL:?Set SUPABASE_DB_URL to the Supabase session-pooler/direct database URL}"
: "${BACKUP_ENCRYPTION_PASSPHRASE:?Set BACKUP_ENCRYPTION_PASSPHRASE before creating a backup}"

command -v supabase >/dev/null 2>&1 || { echo "Supabase CLI is required." >&2; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "Docker is required by supabase db dump." >&2; exit 1; }
command -v openssl >/dev/null 2>&1 || { echo "OpenSSL is required for backup encryption." >&2; exit 1; }
command -v sha256sum >/dev/null 2>&1 || { echo "sha256sum is required." >&2; exit 1; }

umask 077
BACKUP_DIR="${BACKUP_DIR:-./backups}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
WORK_DIR="$(mktemp -d)"
OUT_FILE="${BACKUP_DIR}/dhisme-pos-${STAMP}.tar.gz.enc"
CHECKSUM_FILE="${OUT_FILE}.sha256"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$BACKUP_DIR"

echo "Creating Supabase logical backup at ${STAMP}..."

supabase db dump --db-url "$SUPABASE_DB_URL" \
  -f "$WORK_DIR/roles.sql" --role-only

supabase db dump --db-url "$SUPABASE_DB_URL" \
  -f "$WORK_DIR/schema.sql"

supabase db dump --db-url "$SUPABASE_DB_URL" \
  -f "$WORK_DIR/data.sql" --use-copy --data-only \
  -x "storage.buckets_vectors" -x "storage.vector_indexes"

# Preserve migration history separately because Supabase-managed schemas are
# filtered from the normal dump.
supabase db dump --db-url "$SUPABASE_DB_URL" \
  -f "$WORK_DIR/history_schema.sql" --schema supabase_migrations

supabase db dump --db-url "$SUPABASE_DB_URL" \
  -f "$WORK_DIR/history_data.sql" --use-copy --data-only --schema supabase_migrations

for file in roles.sql schema.sql data.sql history_schema.sql history_data.sql; do
  test -s "$WORK_DIR/$file" || { echo "Backup component is empty: $file" >&2; exit 1; }
done

(
  cd "$WORK_DIR"
  sha256sum roles.sql schema.sql data.sql history_schema.sql history_data.sql > SHA256SUMS
  printf 'created_utc=%s\nformat=supabase-logical-v1\n' "$STAMP" > BACKUP_METADATA.txt
  tar -czf backup.tar.gz \
    BACKUP_METADATA.txt SHA256SUMS roles.sql schema.sql data.sql history_schema.sql history_data.sql
)

openssl enc -aes-256-cbc -salt -pbkdf2 \
  -in "$WORK_DIR/backup.tar.gz" \
  -out "$OUT_FILE" \
  -pass env:BACKUP_ENCRYPTION_PASSPHRASE

sha256sum "$OUT_FILE" > "$CHECKSUM_FILE"

echo "Backup complete: $OUT_FILE"
echo "Checksum: $CHECKSUM_FILE"
echo "Store the encrypted backup and passphrase separately in secure off-site locations."

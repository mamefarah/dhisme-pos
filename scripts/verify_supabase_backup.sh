#!/usr/bin/env bash
set -euo pipefail

# Verifies an encrypted backup produced by backup_supabase.sh without restoring it.
# Usage: BACKUP_ENCRYPTION_PASSPHRASE='...' ./scripts/verify_supabase_backup.sh path/to/backup.tar.gz.enc

: "${BACKUP_ENCRYPTION_PASSPHRASE:?Set BACKUP_ENCRYPTION_PASSPHRASE before verifying a backup}"

BACKUP_FILE="${1:-}"
if [ -z "$BACKUP_FILE" ] || [ ! -f "$BACKUP_FILE" ]; then
  echo "Usage: BACKUP_ENCRYPTION_PASSPHRASE='...' $0 <backup.tar.gz.enc>" >&2
  exit 1
fi

command -v openssl >/dev/null 2>&1 || { echo "OpenSSL is required." >&2; exit 1; }
command -v sha256sum >/dev/null 2>&1 || { echo "sha256sum is required." >&2; exit 1; }
command -v tar >/dev/null 2>&1 || { echo "tar is required." >&2; exit 1; }

WORK_DIR="$(mktemp -d)"
cleanup() { rm -rf "$WORK_DIR"; }
trap cleanup EXIT

SIDE_CAR="${BACKUP_FILE}.sha256"
if [ -f "$SIDE_CAR" ]; then
  (
    cd "$(dirname "$BACKUP_FILE")"
    sha256sum -c "$(basename "$SIDE_CAR")"
  )
else
  echo "Warning: outer encrypted-file checksum sidecar not found; continuing with internal verification." >&2
fi

openssl enc -d -aes-256-cbc -pbkdf2 \
  -in "$BACKUP_FILE" \
  -out "$WORK_DIR/backup.tar.gz" \
  -pass env:BACKUP_ENCRYPTION_PASSPHRASE

tar -xzf "$WORK_DIR/backup.tar.gz" -C "$WORK_DIR"

for file in BACKUP_METADATA.txt SHA256SUMS roles.sql schema.sql data.sql history_schema.sql history_data.sql; do
  test -s "$WORK_DIR/$file" || { echo "Missing or empty backup component: $file" >&2; exit 1; }
done

(
  cd "$WORK_DIR"
  sha256sum -c SHA256SUMS
)

echo "Backup integrity verification passed."
cat "$WORK_DIR/BACKUP_METADATA.txt"
echo "No restore was performed."

#!/usr/bin/env bash
set -euo pipefail

# Generates a long-lived Android upload/release key locally.
# The keystore is intentionally created outside the repository by default.
# keytool prompts for passwords interactively so secrets are not embedded here.

command -v keytool >/dev/null 2>&1 || {
  echo "keytool is required. Install/use JDK 17 and try again." >&2
  exit 1
}

KEYSTORE_PATH="${1:-$HOME/dhisme-pos-upload.jks}"
KEY_ALIAS="${ANDROID_KEY_ALIAS:-dhisme-upload}"

if [ -e "$KEYSTORE_PATH" ]; then
  echo "Refusing to overwrite existing keystore: $KEYSTORE_PATH" >&2
  exit 1
fi

mkdir -p "$(dirname "$KEYSTORE_PATH")"
umask 077

keytool -genkeypair -v \
  -keystore "$KEYSTORE_PATH" \
  -alias "$KEY_ALIAS" \
  -keyalg RSA \
  -keysize 4096 \
  -validity 10000

chmod 600 "$KEYSTORE_PATH"

echo
echo "Created Android upload/release keystore: $KEYSTORE_PATH"
echo "Alias: $KEY_ALIAS"
echo
echo "Back up this keystore securely in at least two protected locations."
echo "Do not commit it to Git. Losing the signing key can block future upgrades."
echo
echo "For GitHub Actions configure these repository secrets:"
echo "  ANDROID_KEYSTORE_BASE64  = base64 of the keystore file"
echo "  ANDROID_KEY_ALIAS        = $KEY_ALIAS"
echo "  ANDROID_STORE_PASSWORD   = the keystore password you entered"
echo "  ANDROID_KEY_PASSWORD     = the key password you entered"
echo
echo "To create the base64 value without storing another plaintext file:"
echo "  python3 -c 'import base64,sys; print(base64.b64encode(open(sys.argv[1],\"rb\").read()).decode())' '$KEYSTORE_PATH'"

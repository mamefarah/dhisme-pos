# Dukaan Dhisme POS — Android Release Signing

## Release model

Dukaan Dhisme POS now has two intentionally separate Android channels:

### Validation channel

- Built by `Build Dukaan Dhisme POS Validation APK`.
- Release-mode Flutter/Android compilation.
- Explicitly uses the Android **debug signing key** through `validationBuild=true`.
- Intended only for controlled pilot installation and functional testing.
- Artifact retention is one day to limit GitHub Actions storage use.
- Must never be presented as the production release.

### Production channel

- Built only by the manual `Produce Signed Android Release` workflow.
- Requires protected Android signing credentials.
- Produces a signed APK and Android App Bundle (AAB).
- Fails if the signing secrets are absent.
- Verifies the APK/AAB signatures and rejects an Android Debug certificate.
- Produces SHA-256 checksums and release metadata.

## Application ID

The application ID is frozen as:

`com.dukaandhisme.dhisme_pos`

Do not change it after pilot distribution unless you intentionally want Android to treat the app as a different application. Keeping it stable allows later signed releases to follow the intended upgrade path, subject to signing-key compatibility.

## Generate the long-lived upload/release key

Run on a secure machine with JDK 17:

```bash
bash scripts/generate_android_upload_key.sh
```

Default output:

`~/dhisme-pos-upload.jks`

The script does not embed passwords; `keytool` prompts for them interactively.

### Key custody

The signing keystore is a critical business asset.

- Keep at least two protected backups of the keystore.
- Keep passwords in a password manager/secrets manager, not in the repository.
- Do not email or WhatsApp the raw keystore/passwords.
- Do not commit `.jks`, `.keystore`, `key.properties`, or base64 keystore material.
- Record who controls the signing key and the recovery process.

## GitHub Actions secrets required

Configure these repository secrets before running the production workflow:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY` — client-key slot only: use an `sb_publishable_...` key or legacy anon JWT (`role=anon`). Never use an `sb_secret_...` key or legacy `service_role` JWT. Both Android workflows fail before compilation if a privileged key is supplied.
- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEY_ALIAS`
- `ANDROID_STORE_PASSWORD`
- `ANDROID_KEY_PASSWORD`

Generate the keystore base64 value locally:

```bash
python3 -c 'import base64,sys; print(base64.b64encode(open(sys.argv[1],"rb").read()).decode())' ~/dhisme-pos-upload.jks
```

Paste that output into the `ANDROID_KEYSTORE_BASE64` GitHub secret. Do not save the base64 value in the repository.

## Local release signing

For a local production build, create ignored `android/key.properties`:

```properties
storeFile=/absolute/path/to/dhisme-pos-upload.jks
storePassword=...
keyAlias=dhisme-upload
keyPassword=...
```

Then run:

```bash
flutter build appbundle --release \
  --dart-define=SUPABASE_URL='...' \
  --dart-define=SUPABASE_ANON_KEY='...'
```

The Gradle configuration refuses a production release task when neither protected environment signing credentials nor local `key.properties` are available.

## Production workflow procedure

After all controlled-pilot gates pass:

1. Confirm `main` is the intended release commit.
2. Confirm `pubspec.yaml` version/build number is incremented.
3. Confirm the production signing secrets are configured.
4. Manually run `Produce Signed Android Release` in GitHub Actions.
5. Require all analyzer/tests/build/signature-verification steps to pass.
6. Download the one-day production artifact.
7. Verify `RELEASE_METADATA.txt` and `SHA256SUMS`.
8. Install the signed APK on a test device.
9. Verify upgrade behavior from the pilot build. Because a debug-signed pilot APK and production-signed APK use different certificates, Android will normally not allow an in-place upgrade between them; plan a clean uninstall/reinstall for transition unless the pilot itself is signed with the production key.
10. For Play distribution, upload the verified AAB according to the chosen Play App Signing/upload-key model.

## Important pilot signing decision

A debug-signed validation APK is safe for functional testing but **cannot normally be upgraded in place to a differently signed production APK with the same application ID**.

Therefore, before putting meaningful long-lived local app state on pilot phones, choose one of these approaches:

- **Preferred for upgrade testing:** configure the production/upload key first and make the pilot candidate with the same signing identity used for the later release; or
- use the debug-signed validation build knowing the transition to production will require uninstall/reinstall on the pilot devices.

The authoritative business data remains in Supabase, but local session/preferences should still be treated as disposable during a debug-signed pilot.

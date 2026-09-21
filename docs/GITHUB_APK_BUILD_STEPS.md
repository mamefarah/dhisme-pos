# GITHUB APK BUILD STEPS

Use this when GitHub should build the non-production validation APK.

## 1. Repository requirements

The committed Android project is required. The workflow verifies these files and fails if they are missing:

```text
android/app/build.gradle.kts
android/app/src/main/AndroidManifest.xml
android/gradlew
android/gradle/wrapper/gradle-wrapper.jar
```

The workflow does **not** run `flutter create` to regenerate Android files.

## 2. Configure Supabase client secrets

Open:

```text
GitHub repository → Settings → Secrets and variables → Actions
```

Configure:

```text
SUPABASE_URL
SUPABASE_ANON_KEY
```

`SUPABASE_ANON_KEY` is a client-key slot only. It must contain either:

- a modern Supabase publishable key beginning with `sb_publishable_`; or
- a legacy anon JWT whose payload role is `anon`.

Never put an `sb_secret_` key or legacy `service_role` JWT in a mobile-build secret. Those are privileged server credentials and must never be compiled into an APK/AAB.

Both Android workflows perform a fail-fast client-key check before compiling.

## 3. Run the validation build

Open:

```text
Actions → Build Dukaan Dhisme POS Validation APK → Run workflow
```

The workflow runs:

1. dependency resolution;
2. splash/icon generation;
3. `flutter analyze --fatal-infos`;
4. `flutter test --coverage`;
5. `flutter build apk --release`;
6. checksum generation.

This is a **release-mode validation APK using debug/validation signing**, not a production-signed release.

## 4. Download the validation artifact

For a manually dispatched successful run:

```text
Actions → successful validation run → Artifacts → dukaan-dhisme-pos-validation-apk
```

The artifact contains:

```text
app-release.apk
BUILD_CHANNEL.txt
SHA256SUMS
```

Artifact retention is one day. Push-triggered runs validate/build but do not upload the artifact.

## 5. Production releases

Do not use the validation artifact as the production release.

Production APK/AAB creation uses the separate manual workflow:

```text
Produce Signed Android Release
```

See `docs/ANDROID_RELEASE_SIGNING.md`.

## 6. Security incident rule

If an APK/AAB is ever found to contain a privileged Supabase key:

1. stop distributing the artifact;
2. remove exposed artifacts;
3. rotate/revoke the compromised key in Supabase;
4. replace `SUPABASE_ANON_KEY` with the current publishable/anon client key;
5. rebuild and verify the new APK before installation.

# GITHUB APK BUILD STEPS

Use this when you want GitHub to build the APK automatically.

## 1. Create a GitHub repository

Create a new empty repository, for example:

```text
dhisme-pos
```

## 2. Upload this project

Upload all files and folders from this package to the repository root.

Important folders/files:

```text
lib/
supabase/
pubspec.yaml
.github/workflows/build-apk.yml
```

The package does not need the Android folder before upload. The workflow will create Android project files automatically using:

```bash
flutter create . --project-name dhisme_pos --platforms=android
```

## 3. Add Supabase secrets

Open GitHub repository:

```text
Settings → Secrets and variables → Actions → New repository secret
```

Add these two secrets:

```text
SUPABASE_URL
SUPABASE_ANON_KEY
```

Use your Supabase Project URL and anon public key.

## 4. Run the build

Open:

```text
Actions → Build Dhisme POS Android APK → Run workflow
```

## 5. Download APK

After the workflow is green:

```text
Actions → latest successful run → Artifacts → dhisme-pos-debug-apk
```

Download and install the APK on your Android phone.

## 6. Common failures

### Missing Supabase keys

The APK may still build, but login will not work if the secrets are empty.

### Flutter package errors

Open the failed action log and send the screenshot/error to ChatGPT for fixing.

### Android signing

This workflow builds a debug APK first. For Play Store or client distribution, create a signed release APK later.

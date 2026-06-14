# FULL APP BUILD NOTE

This package contains the complete Dhisme POS Flutter + Supabase MVP source code and GitHub APK build workflow.

## Included

- Flutter source code
- Supabase backend SQL migration
- Seed data
- Owner/seller login flow
- Owner dashboard
- Seller dashboard
- Product and stock management
- Customer/debt management
- Seller POS screen
- Credit sale approval flow
- Daily cash closing flow
- RLS policies
- Secure PostgreSQL functions
- GitHub Actions APK builder
- Local Windows build script
- Local Linux/macOS build script

## APK status

This ChatGPT sandbox does not have Flutter SDK installed, so the APK was not compiled here.

To get the APK, use either:

1. GitHub Actions workflow included in `.github/workflows/build-apk.yml`
2. Local build script after installing Flutter and Android Studio

## Build command

```bash
flutter build apk --debug --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
```

APK output:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

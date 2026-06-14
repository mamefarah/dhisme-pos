#!/usr/bin/env bash
set -e
# Build Dhisme POS APK locally on Linux/macOS.
# Replace these with your Supabase values before running.
SUPABASE_URL="https://YOUR_PROJECT_ID.supabase.co"
SUPABASE_ANON_KEY="YOUR_SUPABASE_ANON_KEY"

if [ ! -d "android" ]; then
  flutter create . --project-name dhisme_pos --platforms=android
fi

flutter clean
flutter pub get
flutter build apk --debug --dart-define=SUPABASE_URL="$SUPABASE_URL" --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
echo "APK created at: build/app/outputs/flutter-apk/app-debug.apk"

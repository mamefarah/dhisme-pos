# Build Dhisme POS APK locally on Windows PowerShell
# 1) Replace the two values below with your Supabase values.
# 2) Run from the project root: powershell -ExecutionPolicy Bypass -File scripts/build_local_windows.ps1

$SUPABASE_URL = "https://YOUR_PROJECT_ID.supabase.co"
$SUPABASE_ANON_KEY = "YOUR_SUPABASE_ANON_KEY"

if (-not (Test-Path "android")) {
  flutter create . --project-name dhisme_pos --platforms=android
}

flutter clean
flutter pub get
flutter build apk --debug --dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY

Write-Host "APK created at: build/app/outputs/flutter-apk/app-debug.apk"

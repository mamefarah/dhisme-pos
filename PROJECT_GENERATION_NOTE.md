# Important

This package contains the Flutter `lib/`, `pubspec.yaml`, Supabase backend, docs, and setup files.

Because the generation environment did not have Flutter SDK installed, it does not include generated Android Gradle folders from `flutter create`.

To create the full runnable Flutter project:

```bash
flutter create dhisme_pos
copy this package's lib/ pubspec.yaml analysis_options.yaml supabase/ docs/ into the generated dhisme_pos folder
flutter pub get
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

If you want the package to include Android/Gradle files, run `flutter create .` inside this folder after installing Flutter.

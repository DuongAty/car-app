@echo off
REM Convenience wrapper: `run` instead of `flutter run --dart-define=...`.
REM The actual key lives in musicsdk.local.env (gitignored), not in this file.
flutter run --dart-define-from-file=musicsdk.local.env %*

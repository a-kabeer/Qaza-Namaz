# Qaza Namaz — Flutter Project

This repository contains the Qaza Namaz Android app and its domain workflow.

## Current implementation
- Exactly six independent prayer types: Fajr, Zuhr, Asr, Maghrib, Isha, Witr.
- Individual date-based Qaza records.
- Pending/completed state.
- Completion date/time while preserving the original Qaza date.
- Prayer-wise bulk completion.
- Pending counts calculated from records.
- Deterministic record IDs and duplicate protection.
- Basic history/progress calculations.
- Firebase Authentication repository for Google Sign-In.
- Cloud Firestore repository for user-scoped Qaza persistence.
- Firestore security rules scoped to the authenticated Firebase UID.

## Task 2 environment setup
Firebase project configuration is environment-specific. Run `flutterfire configure` locally to generate `lib/firebase_options.dart` and platform configuration for the Android target, then complete Google Authentication and Firestore setup in the Firebase console.

After configuration:

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Do not commit generated local build/cache files such as `.dart_tool/` or `build/`.

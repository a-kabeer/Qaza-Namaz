# Platform Setup

## Android

The current Android application ID and namespace are:

`com.qaza_namaz.com`

The production baseline is:

- compileSdk 36
- targetSdk 36
- NDK 28.2.13676358
- Java 17
- Flutter 3.47.4 in CI

Do not change the NDK version as part of routine maintenance; it is part of the verified build baseline.

## Firebase project

The Android app uses Firebase project:

`qaza-nmz`

Firebase services used by the app are:

- Firebase Authentication
- Google Sign-In
- Cloud Firestore
- Firebase App Check

Firebase is optional at startup. The local encrypted Drift database is authoritative and the normal application can remain usable without network access.

## Google Sign-In

The production Android app must be registered in Firebase using package name `com.qaza_namaz.com`.

Register the production SHA-1 and SHA-256 fingerprints from the official release keystore in Firebase Console. Debug/test fingerprints should be registered separately for local development.

Google Sign-In authentication should be tested on a physical device using the signed release artifact, not only a debug build.

## Firebase App Check

The app activates App Check differently by build context:

- **Release:** Android Play Integrity provider.
- **Debug/test:** Android Debug provider.

In Firebase Console:

1. Register/verify the Android app with package `com.qaza_namaz.com`.
2. Configure the Android App Check provider for Play Integrity for production.
3. Register debug App Check tokens for emulator/developer testing when needed.
4. Verify that the production SHA-256 and Play Integrity configuration correspond to the app distributed for testing.
5. Keep Firestore enforcement enabled only after the physical release build has successfully obtained valid App Check tokens.

The application itself checks that Firebase and App Check are ready before Firestore operations. A failed App Check initialization/token is surfaced as a cloud backup/reconciliation failure while preserving local Qaza state.

## Encrypted local database

The local database is Drift over SQLite with sqlite3/sqlite3mc-backed encryption.

The database key is generated once and stored with `flutter_secure_storage`. Plaintext legacy SQLite files are migrated to an encrypted copy before the normal Drift database is exposed.

A key corruption, sqlite3mc decryption failure, or database migration exception is a fatal local-persistence error and must render the standalone database recovery screen rather than continuing into the main application.

## Commands

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
flutter build appbundle --release
```

## Release signing

Release credentials are provided through `android/key.properties` in secure CI/local environments. `android/app/build.gradle` intentionally does not fall back to debug signing when release credentials are unavailable.

Before a production release, verify:

- AAB builds successfully in CI.
- The official release SHA-256 is registered in Firebase.
- Google Sign-In works on a physical signed release device.
- App Check/Play Integrity succeeds on that signed release device.
- Firestore writes and restore complete without authorization failures.

## Repository governance

The `main` branch should be protected in GitHub with required CI status checks, required pull-request reviews, and no direct pushes. These are repository settings and must be applied by an administrator in GitHub.


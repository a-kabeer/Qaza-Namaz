# Qaza Namaz

Qaza Namaz is an offline-first Flutter Android application for tracking missed prayers (Qaza Namaz). Local persistence is authoritative for day-to-day use; optional Google/Firebase connectivity provides cloud backup and restore without making Firebase a startup dependency.

## Architecture

The app uses a dual-stack persistence model:

- **Local stack — authoritative/offline-first:** Flutter + Riverpod + encrypted Drift/SQLite. The database is opened through the app's sqlite3/sqlite3mc integration and the database key is stored in Android-secured storage.
- **Cloud stack — optional:** Firebase Authentication with Google Sign-In, Firestore backup/reconciliation, and Firebase App Check. Cloud initialization is deliberately post-startup where possible so an unavailable network does not block the local workspace.
- **Migration:** legacy SharedPreferences/Qaza data is migrated into Drift during startup before account-scoped repositories are exposed.
- **Diagnostics:** failures are recorded through the internal diagnostics abstraction with redaction so identifiers, dates, tokens, and ledger values are not persisted as raw diagnostics.

### Startup safety boundary

Startup initializes Flutter and local prerequisites first. Encrypted database opening, key validation/decryption, plaintext-to-encrypted migration, and Drift migration are treated as a fatal persistence boundary. A database failure renders a standalone recovery screen and does not launch the normal Riverpod application.

Profile loading is a separate boundary: `AsyncData(null)` means a legitimate new user, while `AsyncError` means local persistence/provider failure and routes to a retryable error state rather than onboarding.

## Main feature layers

`lib/domain/` contains entities and business rules.

`lib/data/local/` contains the Drift database, account-scoped stores, repositories, migrations, outbox, metadata, and tombstones.

`lib/data/remote/` contains Firebase initialization, Google authentication, cloud backup, reconciliation, and backup failure classification.

`lib/features/` contains onboarding, Qaza workspace/history, home dashboard, prayer times, account settings, analytics, and the application shell.

`lib/l10n/` contains English and Urdu ARB resources. Urdu UI uses the bundled **Noto Nastaliq Urdu** typography and RTL layout rules.

## Cloud data model

Firestore data is scoped below `users/{firebaseUid}`. Qaza records live under `qazaRecords/{recordId}` and use a versioned envelope with schema metadata plus a validated Qaza payload.

Qaza payloads require:

- `id`
- `userId`
- `prayerType`: `fajr`, `zuhr`, `asr`, `maghrib`, `isha`, `witr`
- `status`: `pending` or `completed`
- `originalDate`
- `createdAt`
- `updatedAt`
- `recordVersion`

Firestore Rules validate ownership, lifecycle/generation metadata, payload shape, required keys, dates, and enum values before writes are accepted.

## Android build baseline

- Flutter: **3.47.4** in CI
- Dart: the version bundled with the CI Flutter toolchain
- Android package/application ID: **com.qaza_namaz.com**
- Compile SDK: **36**
- Target SDK: **36**
- NDK: **28.2.13676358**
- Java/Kotlin target: **JDK 17**
- Release signing: production keystore only; release builds never fall back to debug signing

## Firebase / App Check

Firebase uses project ID `qaza-nmz`.

Google Sign-In and Firestore require Firebase initialization. App Check is activated with:

- Android release: **Play Integrity**
- Android debug/test: **Android Debug Provider**

Production Firebase Console configuration must contain the official Android app package and the SHA-256 fingerprint(s) for the release keystore. Google Sign-In and App Check must be exercised on a physical release build before distribution.

## Development

Install dependencies:

```bash
flutter pub get
```

Run static analysis and tests:

```bash
flutter analyze
flutter test
```

Build release artifacts:

```bash
flutter build apk --release
flutter build appbundle --release
```

Firestore security rules can be exercised against the Firebase Emulator Suite with the repository's Node-based emulator test harness.

## CI and release governance

The workflow in `.github/workflows/flutter-ci.yml` performs formatting analysis, unit/widget tests, Firestore rules tests where configured, and release APK/AAB builds.

The protected `main` branch should require green CI and approved pull requests, with direct pushes restricted. Repository administrators must apply these settings in GitHub because they are repository-level controls rather than source-code configuration.

## Dependency policy

All direct dependencies in `pubspec.yaml` are explicitly constrained; no direct dependency uses `any`. Riverpod remains on its current major version for this milestone. A dedicated Riverpod 3 migration should be treated as a separate, planned change rather than mixed into security hardening.

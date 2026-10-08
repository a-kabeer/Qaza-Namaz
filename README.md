# Qaza Namaz

Qaza Namaz is a completely offline Flutter Android application for tracking missed prayers (Qaza Namaz). Local encrypted SQLite persistence is authoritative and the production app does not require an account, cloud service, or internet connection.

## Architecture

The app uses a local-only persistence model:

- **Local stack:** Flutter + Riverpod + encrypted Drift/SQLite. The database is opened through the app's sqlite3/sqlite3mc integration and the database key is stored in Android-secured storage.
- **Account model:** one local device account/session. There is no account-provider sign-in and no cloud identity.
- **Migration:** legacy SharedPreferences/Qaza data is migrated into Drift during startup before account-scoped repositories are exposed.
- **Diagnostics:** failures are recorded through the internal diagnostics abstraction with redaction so identifiers, dates, tokens, and ledger values are not persisted as raw diagnostics.

### Startup safety boundary

Startup initializes Flutter and local prerequisites first. Encrypted database opening, key validation/decryption, plaintext-to-encrypted migration, and Drift migration are treated as a fatal persistence boundary. A database failure renders a standalone recovery screen and does not launch the normal Riverpod application.

Profile loading is a separate boundary: `AsyncData(null)` means a legitimate new user, while `AsyncError` means local persistence/provider failure and routes to a retryable error state rather than onboarding.

## Main feature layers

`lib/domain/` contains entities and business rules.

`lib/data/local/` contains the Drift database, account-scoped stores, repositories, migrations, local metadata, and tombstones.

There is no `lib/data/remote/` runtime layer in the production application.

`lib/features/` contains onboarding, Qaza workspace/history, home dashboard, prayer times, account settings, analytics, and the application shell.

`lib/l10n/` contains English and Urdu ARB resources. Urdu UI uses the bundled **Noto Nastaliq Urdu** typography and RTL layout rules.

## Local data model

Qaza records are stored in the encrypted local SQLite database and are scoped to the single local device account. No cloud identifiers or remote synchronization are required for normal operation.

## Android build baseline

- Flutter: **3.47.4** in CI
- Dart: the version bundled with the CI Flutter toolchain
- Android package/application ID: **com.qaza_namaz.com**
- Compile SDK: **36**
- Target SDK: **36**
- NDK: **28.2.13676358**
- Java/Kotlin target: **JDK 17**
- Release signing: production keystore only; release builds never fall back to debug signing

## Offline requirement

All core application features are designed to function with network access disabled. Location uses the device GPS and bundled offline GeoNames data; prayer-time and Qibla calculations run locally.

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

## CI and release governance

The workflow in `.github/workflows/flutter-ci.yml` performs offline architecture checks, formatting analysis, unit/widget tests, and release APK/AAB builds.

The protected `main` branch should require green CI and approved pull requests, with direct pushes restricted.

## Dependency policy

All direct dependencies in `pubspec.yaml` are explicitly constrained; no direct dependency uses `any`. Riverpod remains on its current major version for this milestone. A dedicated Riverpod 3 migration should be treated as a separate, planned change rather than mixed into security hardening.

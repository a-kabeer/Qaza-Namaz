# Isolated Supabase + PowerSync PoC package

This package is a disposable **Run A experiment**, not part of the production app. It owns its own manifest and generated lockfile under `poc/supabase_powersync/`; do not add these dependencies to the root app or `apps/qaza_app_cloud`.

## Scope

Current task: POC-0 toolchain, exact dependency resolution, license-file inventory, and clean production architecture-boundary checks. No Supabase project, app credentials, OAuth client, or remote database is needed for POC-0.

The first dependency snapshot is deliberately pinned to exact versions:

| Package | Version |
|---|---:|
| `powersync` | `2.5.0` |
| `sqlite_async` | `0.14.6` |
| `drift_sqlite_async` | `0.3.1` |
| `drift` | `2.35.0` |
| `sqlite3` | `3.6.0` |
| `supabase_flutter` | `2.18.3` |
| `flutter_lints` (dev) | `6.0.0` |
| `build_runner` (dev) | `2.16.2` |
| `drift_dev` (dev) | `2.35.2` |
| `analyzer` (dev-tool compatibility pin) | `14.5.0` |
| `async` (dev/test utility) | `2.13.1` |

The original dependency bootstrap reported that `sqlite_async 0.14.6` was available above the previous `0.14.5` pin, so this experiment refreshes the pin before committing its lockfile. The first code-generation run failed because build_runner 2.16.1's resolver did not compile against analyzer 14.6.0 and still failed when analyzer was pinned to 14.5.0. The current build_runner changelog explicitly says 2.16.2 supports analyzer 14.5.0, so the PoC now uses build_runner 2.16.2, drift_dev 2.35.2, and analyzer 14.5.0. This is an isolated development-tool compatibility check, not a production dependency change. Versions are a PoC snapshot, not a promise that the combinations work together. The SQLite package pin matches the root app's current locked `sqlite3` version `3.6.0`, and the build hook matches its `sqlite3mc` selection. Neither proves PowerSync encryption compatibility.

## Run

From this directory, with a compatible Flutter SDK:

```powershell
flutter --version
dart --version
flutter pub get
dart pub deps --style=compact
```

The dedicated CI workflow also records Java, Docker/Compose and Supabase CLI versions and runs the root architecture checks from a separate clean checkout of `main`.

## Lockfile bootstrap

The first CI run is expected to generate `pubspec.lock` and upload it as a short-retention evidence artifact. Commit the generated lockfile to this isolated branch only, then rerun the workflow with lockfile enforcement. POC-0 is not complete until the checked-in lockfile resolves without change.

## Guardrails

- Do not copy this package into `lib/`, `apps/qaza_app_cloud/`, or another production package.
- Do not alter the root app manifest/lockfiles, database schema, or app behavior.
- Do not use personal or production credentials, nor create a hosted/paid service.
- Never weaken the root architecture checkers to make an experiment pass.
- A passing POC-0 does not mean data sync, RLS, Google Auth or every later PoC has passed. The CI workflow additionally runs synthetic encrypted-database tests on a Linux runner and in an Android emulator, including a release APK build.

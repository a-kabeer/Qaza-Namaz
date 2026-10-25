# Isolated Supabase + PowerSync PoC package

This package is a disposable **Run A experiment**, not part of the production app. It owns its own manifest and generated lockfile under `poc/supabase_powersync/`; do not add these dependencies to the root app or `apps/qaza_app_cloud`.

## Scope

Current task: POC-0 toolchain, exact dependency resolution, license-file inventory, and clean production architecture-boundary checks. No Supabase project, app credentials, OAuth client, or remote database is needed for POC-0.

The first dependency snapshot is deliberately pinned to exact versions:

| Package | Version |
|---|---:|
| `powersync` | `2.5.0` |
| `sqlite_async` | `0.14.5` |
| `drift_sqlite_async` | `0.3.1` |
| `drift` | `2.35.0` |
| `sqlite3` | `3.5.2` |
| `supabase_flutter` | `2.18.3` |
| `flutter_lints` (dev) | `6.0.0` |

Versions are a PoC snapshot, not a promise that the combinations work together. Resolve them in CI before adding any implementation code. The SQLite build hook matches the root app's current `sqlite3mc` selection but does **not** prove PowerSync encryption compatibility.

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
- A passing POC-0 does not mean encryption, data sync, RLS, Google Auth or any later PoC has passed.

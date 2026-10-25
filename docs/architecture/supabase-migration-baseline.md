# Supabase Migration Baseline Audit

**Audit date:** 2026-10-25 (Asia/Karachi)  
**Repository:** `a-kabeer/Qaza-Namaz`  
**Audited ref:** `main` at `565d11f4db150ebcb64cb2cf5e96271821a8a997`  
**Feature branch:** `tp-gen/supabase-offline-first`  
**Scope:** Read-only baseline inspection plus a test-harness/CI repair for TP-GEN Run A. No application behavior changes made.

## 1. Repository state and current architecture

The latest inspected remote `main` commit is `565d11f4db150ebcb64cb2cf5e96271821a8a997`, titled **“Remove Google Drive; keep Google identity and local storage.”**

The repository's `AGENTS.md` confirms the application is pre-release and test data is disposable. It explicitly permits a clean storage redesign but still requires correct encryption, isolation, error handling, and meaningful tests. The current instruction text still mentions rebuilding Google authentication, per-account encrypted local databases, and Google Drive backup; this is stale relative to the current `main` commit and should be updated only as part of the approved architecture/cleanup work, not silently treated as a requirement.

Current root app dependencies include Drift `^2.35.0`, SQLite `^3.5.2`, `drift_flutter` `^0.3.1`, `flutter_secure_storage` `^10.3.4`, and a SQLite3MultipleCiphers build hook (`source: sqlite3mc`). The root app uses schema version 26. The optional `apps/qaza_app_cloud` target currently depends on `google_sign_in` and the root app; its description says it is a Google Sign-In/local-only host. Supabase is not currently implemented.

Relevant code inspected:
- `lib/data/local/database/database_encryption.dart`
- `lib/data/local/database/app_database.dart`
- `lib/data/local/database/database_manager.dart`
- `lib/features/account/account_session_manager.dart`
- `lib/features/onboarding/account_choice_screen.dart`
- `lib/app/providers.dart`
- `test/features/onboarding/account_choice_screen_test.dart`
- `tools/offline_architecture_check.py`
- `tools/phase_boundary_check.py`

## 2. Local encryption findings

The current key store uses `flutter_secure_storage` and a 32-byte random key encoded with Base64URL. The key is not intentionally stored in SQLite or SharedPreferences. The database opener applies `PRAGMA key`, checks that cipher support exists, and forces SQLite to validate the key before Drift queries proceed. The root pubspec configures SQLite3MultipleCiphers through the `sqlite3mc` build hook.

These facts establish the current design, not proof that it is the best design for PowerSync. The PoC must verify:
- The exact selected PowerSync version and supported native encryption mode.
- Whether SQLite3MultipleCiphers and SQLCipher alternatives are supported and compatible with the full native dependency graph.
- Drift integration, if retained, including transaction, schema, and connection lifecycle behavior.
- Android release build and reopen/integrity tests using the selected encryption configuration.
- Key loss, reinstall, backup/restore, and signed-out workspace behavior.

No encryption compatibility claim has been made yet.

## 3. Database and account architecture findings

The current code contains a database manager with a control database, a registry, workspace database factories, workspace-opening/provisioning state, and account-session management. The account-choice screen restores Google identity and uses it to select a local workspace; Google identity currently does not imply remote storage.

This is useful audit evidence but does not make per-account databases mandatory. The v1 product scope is one active cloud account per installation, multi-device sync, and local-only guest use. The ADR should compare a single encrypted local database bound to the current guest/authenticated identity against the selected sync engine's managed local database. Multi-account concurrent workspaces are out of scope unless the audit identifies a concrete requirement.

The local-only guest adoption flow remains a product requirement. If an authenticated account already has cloud data, reconciliation must be explicit; no silent overwrite or merge.

## 4. CI-AM baseline audit and verified fix

### Historical failure on main

The baseline main runs were:
- [Flutter CI run 40131841997](https://github.com/a-kabeer/Qaza-Namaz/actions/runs/40131841997)
- [Google Identity App CI run 40131842012](https://github.com/a-kabeer/Qaza-Namaz/actions/runs/40131842012)

Both reported 758 tests passed and four 10-minute timeouts in `test/features/onboarding/account_choice_screen_test.dart`:
1. `Google sign-in creates or resumes a local Google workspace`
2. `Continue as Guest offers saved local workspaces and Start Fresh`
3. `Google sign-in offers an explicit local Guest adoption`
4. `Google identity failure leaves local account choice available`

### Diagnosis and changes

The tests began by creating a real temporary directory, opening an isolate-backed native Drift database, reading its revision, and initializing the account session, all directly inside `testWidgets`' fake-async zone. The tests timed out before mounting the UI. Changing only `pumpAndSettle()` was insufficient. The validated fix was to run filesystem/native database setup, teardown, and direct test database operations via `tester.runAsync`, which lets that real asynchronous work complete outside the fake-async zone.

Additional safety/diagnostic changes:
- Replace `pumpAndSettle()` with bounded waits for the expected button/dialog/route state.
- Cap each of the four regressions at 45 seconds.
- Run each named regression test as a preflight before Drift code generation and the full suite.
- Preserve all four tests and their assertions. No application/product behavior changed.

### Verification

- [Flutter CI run 40170592701](https://github.com/a-kabeer/Qaza-Namaz/actions/runs/40170592701): success. Account-choice preflight passed; root `flutter test --coverage` full suite passed. The job's formatter pushed format-only commit `c4f0004b960b5afe9a0c3ce39b4f09ae28d77fee` and full tests passed in the same job after formatting.
- [Google Identity App CI run 40170592703](https://github.com/a-kabeer/Qaza-Namaz/actions/runs/40170592703): success. Account-choice preflight and full offline-app suite passed; Google identity host tests passed; the Google identity Android release APK built successfully.
- These runs used Flutter `3.47.4`. CI-AM is **COMPLETE / GREEN** for this baseline timeout. The original failed runs remain above as historical evidence.

## 5. Environment readiness

Not yet verified in a runnable developer environment:
- Flutter/Dart and Android SDK matching the repository's configured toolchain.
- Docker and Supabase CLI for local Supabase testing.
- PowerSync local/hosted development service access.
- Android emulator or physical device for encrypted database and release smoke tests.
- Safe local/CI secret storage for test credentials.

GitHub Actions successfully ran the root Flutter tests, the offline-app test suite, Google identity host tests, and the Android host APK build. This session still has no local checked-out working tree/Flutter executable for direct shell execution, and Docker/Supabase CLI, an Android emulator/device, and the PowerSync service remain unavailable for the Run A compatibility PoC.

## 6. Architecture research and decision still pending

No sync-engine choice has been made. Run A must verify current official package versions/releases at execution time and perform the focused PowerSync spike, prioritizing encryption and Drift/SQLite integration. If the first encryption option fails, test the other supported documented option before rejecting PowerSync. Compare custom synchronization as a fallback, including implementation and operating costs.

The ADR must address:
- One active authenticated cloud account per installation.
- Local-only guest use and explicit guest adoption.
- Sign-out retention and separate local-data removal behavior.
- Local encryption and key protection/recovery.
- Supabase Auth, RLS, and synchronization authorization.
- Sync conflict, deletion, retry, and account-deletion semantics.
- Cost and operational burden.
- Explicit criteria for switching to custom sync.

## 7. Next steps

1. **COMPLETE — CI-AM:** verified fix and green workflow evidence are recorded in Section 4.
2. Complete the remaining source inventory and environment checks.
3. Perform the focused PowerSync/encryption/Drift proof of concept in an isolated throwaway location.
4. Document custom sync as the fallback and compare costs.
5. Finalize the ADR and present the evidence to the user.
6. **Stop for explicit approval. Do not begin backend implementation before approval.**


## 8. Official documentation research (2026-10-25)

Initial research is recorded here, but it does not replace the required compatibility PoC.

- PowerSync Dart/Flutter SDK `powersync 2.5.0` is published as stable; release notes dated 2026-10-19 describe a web worker protocol change affecting web builds, not native Android. Native SQLCipher support was restored in 2.3.1, while v2.0 added built-in `EncryptionOptions` support for SQLite3 Multiple Ciphers. The PoC must verify the actual native configuration used by this project rather than infer compatibility from release notes.
  - https://releases.powersync.com/announcements/flutter-client-sdk
  - https://pub.dev/packages/powersync
- `drift_sqlite_async 0.3.1` is published as stable and documents Drift query support, transactions/nested transactions, update propagation, and optional Drift migrations over `sqlite_async`. Its package dependencies include `drift`, `sqlite3`, and `sqlite_async`; compatibility with PowerSync's selected encrypted connection remains unproven until tested.
  - https://pub.dev/packages/drift_sqlite_async
  - https://pub.dev/packages/drift_sqlite_async/versions
- Supabase's PowerSync integration describes a client-side SQLite database, Sync Rules/Streams, upload queue, Supabase Auth integration, and server-side custom conflict handling. PowerSync is therefore a credible leading candidate, not yet the selected architecture.
  - https://supabase.com/partners/catalog/powersync
- Pricing observed during this audit: Supabase Free is $0 with 500 MB database, 50,000 MAU, and projects paused after one week of inactivity; Supabase Pro starts at $25/month. PowerSync Cloud Free is $0 with soft limits, 2 GB synced/month, 500 MB hosted data, 50 peak concurrent clients, and project deactivation after one week of inactivity; PowerSync Cloud Pro starts at $49/month. Prices and plan limits can change; verify before provisioning. No paid service is authorized by this audit.
  - https://supabase.com/pricing
  - https://powersync.com/pricing
- Supabase RLS guidance recommends explicit per-operation policies, roles such as `to authenticated`, ownership expressions using `(select auth.uid())`, indexes for policy predicates, and `security_invoker = true` for exposed views where appropriate. The future implementation should include pgTAP tests in `supabase/tests/` and run `supabase test db` in CI.
  - https://supabase.com/docs/guides/database/postgres/row-level-security

### Preliminary candidate assessment (not an ADR decision)

PowerSync is the leading candidate to test first because it provides the synchronization queue and local SQLite model, which can avoid a custom sync engine. The largest unresolved risk is whether its supported encryption configuration, database lifecycle, and optional Drift integration can coexist cleanly with the app's current SQLite3MultipleCiphers/native dependencies and one-active-account requirement. If supported PowerSync configurations fail the focused PoC, compare the maintenance cost of a custom transactional outbox against using PowerSync without Drift. Do not select either option until the evidence is recorded.

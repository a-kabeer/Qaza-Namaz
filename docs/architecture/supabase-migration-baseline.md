# Supabase Migration Baseline Audit

**Audit date:** 2026-10-25 (Asia/Karachi)  
**Repository:** `a-kabeer/Qaza-Namaz`  
**Audited ref:** `main` at `565d11f4db150ebcb64cb2cf5e96271821a8a997`  
**Feature branch:** `tp-gen/supabase-offline-first`  
**Scope:** Read-only baseline inspection for TP-GEN Run A. No application behavior changes made.

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

## 4. CI-AM baseline audit

Latest inspected runs for the audited main SHA:
- [Flutter CI run 40131841997](https://github.com/a-kabeer/Qaza-Namaz/actions/runs/40131841997)
- [Google Identity App CI run 40131842012](https://github.com/a-kabeer/Qaza-Namaz/actions/runs/40131842012)

Both failed in their test job with the same four 10-minute timeouts in `test/features/onboarding/account_choice_screen_test.dart`:
1. `Google sign-in creates or resumes a local Google workspace`
2. `Continue as Guest offers saved local workspaces and Start Fresh`
3. `Google sign-in offers an explicit local Guest adoption`
4. `Google identity failure leaves local account choice available`

The logs report 758 tests passed and four failed. The root Flutter CI's Android release artifacts job succeeded. The Google Identity App CI's Google identity Android host analyze/build job succeeded. The failed test jobs completed the offline architecture policy, phase-boundary policy, dependency/dead-code audit (root workflow), analysis, and formatting steps before timing out during tests.

Both workflow definitions use Flutter `3.47.4`. They also contain branch-push formatting steps that can commit and push formatting changes using the GitHub Actions bot. This behavior should be considered when interpreting feature-branch CI results.

### CI-AM disposition

- Baseline is **RED** and must not be represented as green.
- Four identical long timeouts indicate a shared test/harness path; the logs alone do not prove the root cause.
- The relevant test file's four failing journeys include `pumpAndSettle()` after UI actions and asynchronous account/session/database behavior. This is a diagnostic lead, not a confirmed cause.
- Do not remove tests, weaken assertions, or change application behavior to hide the failures.
- The present execution environment has GitHub read/write integration but no checked-out working tree, Flutter executable, Android SDK/emulator, or Docker/Supabase CLI available. A local targeted reproduction and safe code fix cannot be claimed from this session.
- CI-AM follow-up must run the four tests individually in a working Flutter environment, capture verbose output and the last progress point, identify the common hang, apply the smallest justified test/harness or product fix, then rerun targeted tests and the full CI suite. Preserve the failing baseline evidence.

## 5. Environment readiness

Not yet verified in a runnable developer environment:
- Flutter/Dart and Android SDK matching the repository's configured toolchain.
- Docker and Supabase CLI for local Supabase testing.
- PowerSync local/hosted development service access.
- Android emulator or physical device for encrypted database and release smoke tests.
- Safe local/CI secret storage for test credentials.

This session cannot run `flutter test`, build Android, launch Docker, or execute the PowerSync PoC because the repository is not checked out and external network access from the shell is unavailable. Remote GitHub source and CI results were inspected instead.

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

1. Complete CI-AM by reproducing and resolving the four baseline test timeouts in a runnable Flutter environment.
2. Complete the remaining source inventory and environment checks.
3. Perform the focused PowerSync/encryption/Drift proof of concept in an isolated throwaway location.
4. Document custom sync as the fallback and compare costs.
5. Finalize the ADR and present the evidence to the user.
6. **Stop for explicit approval. Do not begin backend implementation before approval.**

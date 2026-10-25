# Supabase Migration Baseline Audit

**Audit date:** 2026-10-25 (Asia/Karachi)  
**Repository:** `a-kabeer/Qaza-Namaz`  
**Current main reviewed for Run A update:** `4e9747ed2005806ae81ede78ef2448af9b483aa7`  
**Original architecture-code inspection baseline:** `565d11f4db150ebcb64cb2cf5e96271821a8a997`  
**Feature branch:** `tp-gen/supabase-offline-first`  
**Scope:** Read-only baseline inspection plus a test-harness/CI repair for TP-GEN Run A. No application behavior changes made.

## 1. Repository state and current architecture

The original storage/code inspection baseline was commit `565d11f4db150ebcb64cb2cf5e96271821a8a997`, titled **“Remove Google Drive; keep Google identity and local storage.”** The current `main` was revalidated at `4e9747ed2005806ae81ede78ef2448af9b483aa7` after PR #351. That merge fixed CI test timeouts and updated planning documentation; it did not implement Supabase or change production app behavior.

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

## 5. Environment readiness and honest execution state

Official PowerSync documentation confirms a local-development route that self-hosts Supabase and PowerSync with Docker; a public sample repository includes a Supabase demo. Therefore, a hosted project, paid plan, or production credential is not inherently required for the PoC:
- https://docs.powersync.com/integrations/supabase/local-development
- https://github.com/powersync-ja/self-host-demo

**Actual execution status: NOT RUN.** This audit has not executed Docker Compose, Supabase CLI, clean dependency resolution, Android emulator tests, or PowerSync/Drift encryption tests. Existing GitHub Actions prove the current app/CI baseline only; they do not prove that the PoC toolchain is present or that sync compatibility works. Start with PoC-0 on an isolated branch, capture actual command versions/results, then run each experiment in ADR-001's ledger. Do not state that a tool is available until its command output is captured.

The PoC should use only disposable local Docker volumes, synthetic users/data and fresh test keys. Do not configure a hosted service, add a billing subscription, reuse app keys/database files, or put secrets into Git.

## 6. Architecture research summary and decision state

PowerSync + Supabase is the first option to test in a local PoC; it is not selected for production. ADR-001 is the single source of the options analysis, version snapshot, privacy/security risks, workspace alternatives, Qaza conflict policy candidate, estimated costs and quantified PoC/no-go criteria. If the first documented encryption option fails, test the alternate documented cipher option before rejecting PowerSync. Custom sync remains the fallback, with higher implementation/testing/operational burden.

The ADR must address:
- One active authenticated cloud account per installation.
- Local-only guest use and explicit guest adoption.
- Sign-out retention and separate local-data removal behavior.
- Local encryption and key protection/recovery.
- Supabase Auth, RLS, and synchronization authorization.
- Sync conflict, deletion, retry, and account-deletion semantics.
- Cost and operational burden.
- Explicit criteria for switching to custom sync.

## 7. Current Run A status

**Run A: OPEN — blocked on PoC execution.** Research and candidate architecture are documented in [ADR-001](adr-001-supabase-powersync-candidate.md). No sync engine is accepted and no backend code has been implemented.

1. **COMPLETE — repository/code inventory:** encrypted key store/database opener, Drift schema/DAO shape, workspace manager/registry, session/Google identity boundaries, root/host manifests and architecture scripts inspected.
2. **COMPLETE — official-docs/option research:** PowerSync encryption and upload queue, local Docker setup, Sync Streams, Drift integration package, Supabase Auth/RLS and qualitative costs recorded in ADR-001.
3. **OPEN — topology and Qaza conflict policy:** choose W1/W2 based on actual DAO/workspace impact and establish append-only completion/reversal semantics before sync tests.
4. **NOT RUN — POC-0 through POC-8:** local execution is possible in principle without a hosted service. No command/test result is claimed until recorded; keep all tests on a throwaway branch with synthetic data and check-only formatting.
5. **REQUIRED — owner approval:** do not implement backend or change production app behavior until PoC evidence has been added, ADR status has a defensible decision, and the owner explicitly approves.

## 8. Research reference

The original official-documentation research has been consolidated into [ADR-001](adr-001-supabase-powersync-candidate.md), which is the single source for package-version snapshots, options, security and privacy findings, pricing notes and PoC acceptance criteria. This baseline is intentionally focused on repository evidence and environment state so the research narrative does not drift across documents.

Primary links are maintained in ADR-001 §11. Official PowerSync documentation confirms a self-hosted Supabase + PowerSync local development path via Docker. Current PoC execution status remains **NOT RUN**; do not treat documentation support as evidence that this repository's encrypted Drift database works with PowerSync.


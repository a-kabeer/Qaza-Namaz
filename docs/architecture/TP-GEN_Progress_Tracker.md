# TP-GEN Progress Tracker — Separate Encrypted Local Database per Google Account

**Last updated:** 2026-10-24 (Asia/Karachi) — close-race tests passed; analyzer baseline recorded and safe warning fixes committed for verification  
**Repository:** `a-kabeer/Qaza-Namaz`  
**Working branch:** `tp-gen/separate-google-db`  
**Purpose:** Living checkpoint log for the TP-GEN task. Update this file after each meaningful action, test result, decision, or blocker. Record evidence and exact outcomes; never mark a phase complete based only on a plan or an unverified claim.

---

## 1. Goal and safety rules

Deliver a maintainable account/database architecture in which each verified Google account has its own encrypted local SQLite workspace, while the control database holds only the state needed to locate and safely manage workspaces. Google Drive is for backup and recovery, not a shared live database.

Core invariants:

- Route data by the stable, verified Google account ID, not email or display name.
- Account A, Account B, and any supported Guest/recovery workspace must never read or write one another's records.
- Sign-out, offline operation, expired authorization, or backup failure must not delete local records.
- Never silently create an empty replacement for an existing file whose key, schema, integrity, or owner cannot be verified.
- Restore, adoption, migration, and file publication must be staged, verifiable, restart-safe, and retryable.
- Preserve existing backup compatibility unless a deliberate, documented format decision is approved.
- Do not change Qaza calculations or daily Salah tracking as part of this storage refactor.
- Pre-launch test data may be reset only through an explicit, controlled app-owned reset/recovery procedure. Never delete Google accounts, unrelated Drive files, credentials, signing keys, source code, or unrelated user data.
- Never weaken or delete tests solely to obtain a passing result. Do not claim real-device Google/Drive validation unless it was actually performed.

### Scope decision to reconcile before removing Guest paths

The planning materials are not fully aligned: the separate-database implementation plan keeps Guest workspaces in the control database, while the clean-rebuild audit proposes Google-only new-account entry flows with legacy Guest recovery. Before removing Guest runtime code, reconcile these documents and record the approved choice. Until then, preserve existing Guest data and recovery paths; do not silently assign Guest data to a Google account.

---

## 2. Current checkpoint summary

| Area | Status | Evidence / notes |
|---|---|---|
| Branch synchronization | **Done for test checkpoint** | User's PowerShell output confirms fast-forward from `65820a1b` to `5295005a` on `tp-gen/separate-google-db`; `git pull --ff-only` succeeded and the branch was up to date with origin. |
| Local working-tree safety | **Preserve local change** | User reported `pubspec.lock` modified and restored from stash. Do not discard, restore, or commit it without reviewing the diff and asking/confirming as appropriate. |
| Database manager test teardown | **Targeted tests passed** | User ran `flutter test test/data/local/database/database_manager_test.dart test/data/local/database/database_manager_stage4_test.dart`; output ended `All tests passed!`. Drift duplicate-database warnings appeared and remain to be investigated. |
| Qaza screen contract tests | **Passed** | User ran `flutter test test/features/qaza/qaza_tracker_screen_contract_test.dart`; output ended `+53: All tests passed!`. Windows/Unix line-ending normalization is present in the test file on GitHub. |
| Full test suite | **Passed: 800 tests** | User-provided log ends `02:58 +800: All tests passed!` after the rollback-test fake optimization. Output still contains non-fatal Flutter hit-test warnings in `settings_screen_test.dart`, FlexColorScheme theme warnings, and Drift duplicate-database warnings; test success does not clear those follow-up risks. |
| Static analysis | **Ran: 0 errors, 4 warnings, 26 info** | User ran `flutter analyze` on 2026-10-24; output ended `30 issues found` in 158 seconds. Warnings: unnecessary non-null assertion at `local_backup_service.dart:2385`, unused `_selectMaps` at `local_backup_service.dart:3363`, unnecessary non-null assertion at `app_database.dart:104`, unused `_migrateLegacyGoogleWorkspace` at `database_manager.dart:182`. Info includes undeclared direct dependency `uuid` in `account_local_store.dart:5`, several style notices, and deprecated Radio APIs. This result is recorded, not yet treated as final acceptance; review dependency ownership and unused migration/helper code without deleting safety-critical paths blindly. |
| Database/account architecture | **Three close-race tests now passed locally; architecture not yet accepted** | User's local Stage 4 run ended `00:25 +15: All tests passed!`; the combined database-manager run ended `00:20 +22: All tests passed!`. This includes the adoption-publication/close regression test. Drift multiple-instance warnings still appear in migration, safety-copy and staging-file tests; these are not proof of shared-executor reuse by themselves. User's subsequent analyzer baseline has 0 errors, 4 warnings and 27 info. Four warning-level items and the direct `uuid` dependency notice have now been addressed in follow-up commits, but analyzer must be rerun after sync. Full suite and broader architecture gates remain open. |
| Merge/release readiness | **Not ready to declare** | Full suite, static analysis, audit gates, required isolation/recovery coverage and device verification remain outstanding. |

### Relevant commits already present on the branch

- `a6136afb` — close injected control database during database-manager test teardown.
- `c66fa661` — close injected control database during Stage 4 test teardown.
- `72100ea5` — normalize source text across Windows line endings in Qaza contract tests.
- `65820a1b` — format Dart sources; last HEAD confirmed in the user's local checkout before the newest fixes.
- `ee06d889` — make fixed-Hijri test span assertions compare calendar days (DST-safe).
- `54437e76` — make backup timestamp fixture deterministic with an explicit `+05:00` offset.
- `996e8d81` — close the injected control DB in Stage 4 test teardown and close the original manager before deleting an open workspace file.
- `d5697f3e` — normalize Prayer Time UI contract-test source reads across Windows/Unix line endings.
- `72700e14` — replace quadratic scans in the in-memory profile-plan mutation/rollback test fake with set-based checks to prevent the rollback test from stalling.
- `5295005a` — branch tip from the user's successful fast-forward; includes the tracker and the targeted test fixes recorded above.

These commits are recorded from the user's Git output and prior checkpoint context; this tracker does not claim any tests ran on GitHub CI unless separately recorded below.

---

## 3. Staged work plan and gates

### Phase 0 — Reconcile plan and audit current branch
**Status: In progress / needs branch-aware review**

- [ ] Inspect the current branch's actual code rather than relying solely on the earlier remote-`main` audit.
- [ ] Inventory every database constructor, raw SQL caller, DAO/repository/provider dependency, account/session state owner, encryption-key path and WorkManager entry point.
- [ ] Classify tables and `meta_store` keys as control-owned or workspace-owned.
- [ ] Resolve and document the Guest product/recovery policy and reconcile conflicting architecture decision records.
- [ ] Decide the missing/invalid encryption-key contract, cloud-payload confidentiality policy, and migration/reset treatment of legacy development data.
- [ ] Record baseline commands and results on the current commit.

**Gate:** documented evidence and explicit decisions; no production behavior changes during audit.

### Phase 1 — Control database, workspace manager and explicit routing
**Status: Not yet accepted**

- [ ] Control database stores registry/session/device-level state and durable cross-file operation journals only.
- [ ] Introduce one manager that owns database open/close and enforces one managed connection per file.
- [ ] Replace direct production database construction and implicit global-current-account reads with explicit handles/workspace context.
- [ ] Separate key creation for a confirmed new file from opening an existing file with its existing key.
- [ ] Verify owner marker, encryption, schema and integrity before exposing a workspace.

**Gate:** policy and regression tests pass; no data-access path can bypass ownership/routing.

### Phase 2 — One encrypted local database per Google account
**Status: Not yet accepted**

- [ ] Use a stable verified Google ID and opaque, collision-checked file mapping.
- [ ] Create new databases in staging, validate them, and publish via a durable journal/reconciliation protocol.
- [ ] Verify two Google accounts receive different physical files and cannot read/write each other's data.
- [ ] Account switching closes/detaches the old workspace and invalidates stale asynchronous work before publishing the new workspace.
- [ ] Missing/corrupt/wrong-key/wrong-owner/schema-incompatible files fail safely without empty replacement or cross-account fallback.

**Gate:** two-account isolation, restart, corruption and account-switch tests pass.

### Phase 3 — Adoption, backup/restore, export/import and Keep Both
**Status: Not yet accepted**

- [ ] Route every cloud operation to exactly one authenticated Google identity and workspace.
- [ ] Preserve envelope/schema compatibility and validate metadata, hash, read-back and ownership.
- [ ] Use staging and durable journals for restore/adoption; source and recovery files remain available until verification and commit.
- [ ] Handle interrupted operations and retries idempotently.
- [ ] Full local export/import, if retained, explicitly coordinates all registered workspaces and fails rather than exporting/importing a partial set.
- [ ] Preserve both sides of a conflict; never silently merge or overwrite.

**Gate:** failure-invariance, compatibility and fault-injection tests pass.

### Phase 4 — Pre-launch legacy/test-data policy
**Status: Decision and verification required**

- [ ] Explicitly identify legacy shared-layout Google workspace data.
- [ ] Choose and document a bounded conversion/recovery flow or controlled development reset; no silent replacement.
- [ ] Preserve Guest data according to the approved Guest decision.
- [ ] Do not delete old files/rows or cloud backups as incidental migration cleanup.

**Gate:** legacy behavior is explicit, covered by tests, and reviewed before device validation.

### Phase 5 — Final verification and handoff
**Status: Not started**

- [ ] Full test suite passes; investigate all failures rather than suppressing them.
- [ ] Static analysis and formatting checks run on the final diff.
- [ ] Database manager reuses and closes connections safely; investigate the current Drift duplicate-instance warnings.
- [ ] Account lifecycle, cloud adapter, WorkManager, migration, recovery and architecture/phase-boundary checks pass.
- [ ] Required Android build(s) succeed.
- [ ] Real-device checks are documented, including two-account isolation, sign-out/sign-in, app restart, offline changes, backup/restore, and damaged/missing file handling.
- [ ] Review the full diff and local `pubspec.lock` change; record all limitations and evidence.
- [ ] Obtain explicit approval before merge/release actions.

**Gate:** every requirement maps to test/evidence; untested device or cloud cases are clearly labeled; no known data-loss or isolation blocker remains.

---

## 4. Test and issue log

Append new entries at each checkpoint. Keep old failures for history; mark them resolved only after a rerun proves it.

| Date | Check / issue | Result | Follow-up |
|---|---|---|---|
| 2026-10-23 | Earlier full `flutter test` run | **Failed: 14 tests** (`+786 -14`) | Four observed Qaza contract failures were due to line-ending-sensitive source assertions. Other failures need the latest report and targeted reproduction. |
| 2026-10-23/24 | Database-manager and Stage 4 tests | **Passed** | Drift warns about multiple Drift database instances. Investigate safe connection ownership; do not suppress warning without understanding the cause. |
| 2026-10-24 | Qaza screen contract test on synchronized branch | **Passed: 53 tests** | The source-reading helper normalizes CRLF/CR to LF. |
| 2026-10-24 | Latest full-suite rerun (`flutter test --reporter=expanded`) | **Failed: 10 tests** (`+790 -10`; ~29m45s) | `fixed_hijri_arithmetic_service_test.dart`: calendar end-date assertion expected 01:00 but received 00:00, consistent with duration-based addition crossing DST. `local_backup_service_test.dart`: local `DateTime(12:34)` expected as UTC `12:34Z`, but actual conversion was `07:34Z` in UTC+05. Six cases in `stage4_adoption_export_test.dart` failed during temp-file/directory deletion with Windows `errno=32` locked handles. Two `prayer_time_ui_contract_test.dart` cases compared LF literals to CRLF source. Qibla-specific test was separately rerun and passed. |
| 2026-10-24 | Follow-up test-only fixes committed remotely | **Pending local sync and rerun** | `ee06d889` uses calendar-day difference for milestone spans; `54437e76` uses a deterministic explicit-offset timestamp; `996e8d81` closes the injected control DB and original manager before deleting test files; `d5697f3e` normalizes Prayer Time UI contract source line endings. No claim that these fixes pass until the targeted tests are rerun. |
| 2026-10-24 | User synced branch and reran targeted failure groups | **Passed: 4 targeted test files** | `git pull --ff-only origin tp-gen/separate-google-db` fast-forwarded `65820a1b..5295005a`; `pubspec.lock` was stashed/popped and remains modified, not discarded. `flutter test test/core/fixed_hijri_arithmetic_service_test.dart` passed (7 tests); `flutter test test/data/local_backup_service_test.dart` passed (36 tests); `flutter test test/data/stage4_adoption_export_test.dart` passed (6 tests); `flutter test test/features/prayer_time/prayer_time_ui_contract_test.dart` passed (5 tests). Stage 4 emitted repeated Drift warnings about multiple database instances sharing a `QueryExecutor`; investigate rather than suppress. Full-suite rerun remains pending. |
| 2026-10-24 | Static analysis rerun after targeted fixes | **Completed: 0 errors; 4 warnings; 26 info** | User ran `flutter analyze`; completion time 158.0 seconds; final output `30 issues found`. Warnings include unused `_selectMaps` and `_migrateLegacyGoogleWorkspace`, plus unnecessary non-null assertions. An info notice says `uuid` is imported by `account_local_store.dart` but is not a direct dependency. Review code/dependency intent; don't remove migration code or edit dependencies blindly. Static analysis and architecture follow-up remain open. |
| 2026-10-24 | Full-suite test run — apparent stall reported | **Resolved by test-helper optimization; see pass below** | User reported the console remained at `08:15 +796` near `revision failure rolls back the atomic ledger mutation`. The isolated command pointed to `test/domain/profile_qaza_plan_reconciliation_service_test.dart`. Inspection identified quadratic in-memory test-fake scans; they were replaced with set lookups in `72700e14`. The later user-provided log completes the full suite successfully; see the subsequent pass entry. |
| 2026-10-24 | Isolated rollback test inspected; test fake optimized | **Verified by full-suite pass** | The isolated output points to `test/domain/profile_qaza_plan_reconciliation_service_test.dart`. The test stores a prior plan revision but starts with an empty in-memory ledger; `apply` builds additions for the new plan before intentionally failing revision save. `MemoryMutationRepository.applyProfilePlanChanges` previously scanned the growing ledger for each addition (`O(n²)`), and rollback similarly used `mutation.added.any(...)` inside `removeWhere` (`O(n²)`). Changed only the test fake to use a set of Qaza prayer keys and sets of record IDs (`72700e14`). This is a test performance optimization, not a change to production transaction behavior. User's subsequent full test log completed in 2:58 and ended `+800: All tests passed!`; the target test was part of that suite. |
| 2026-10-24 | Full suite after rollback-test optimization | **Passed: 800 tests (~2m58s)** | User-provided output ends `02:58 +800: All tests passed!`. The log includes Flutter hit-test warnings around `settings_screen_test.dart` taps and FlexColorScheme theme-reference warnings, but the test runner completed successfully. Drift duplicate-database warnings are still an architecture risk to investigate. |
| 2026-10-24 | Drift duplicate-database warning — first source audit | **Open; root cause not yet proven** | Reviewed the warning stack in the user-provided full-suite log: the second `AppDatabase` is created at `appDatabaseProvider` in `lib/app/providers.dart` and flows through `databaseManagerProvider` into `qazaLocalStoreProvider` / Qaza actions. Current provider code intentionally injects the exact `appDatabaseProvider` handle into `DatabaseManager`, so those two providers should not by themselves create two control DB objects. Also found `loadInitialHomePrayerSelection()` constructs a standalone `DatabaseManager()` and closes it in `finally`; it is a separate startup handle, but this alone does not prove the warning's same-`QueryExecutor` condition. Do not silence the warning. Next establish the first-instance stack and whether the warning is from concurrent test ProviderContainers or an injected/reused executor, then fix ownership/teardown and add a regression test. |

| 2026-10-24 | Undo-feedback Drift warning reproduction | **3 tests passed; warning reproduced** | User's targeted test warns at `AppDatabase.control()` through `appDatabaseProvider` during Undo Selected. Drift 2.35.0 counts open instances by database runtime type, not executor identity, so this warning alone does not prove a shared executor. The previous Undo All widget test also reads the real service/database graph, and provider close is unawaited; test overlap is plausible but not proven. Commit `eaa7463734d7fc0bda652027c47db5443b08de3e` overrides `qazaServiceProvider` with a fake repository in all three UI tests. Rerun after sync; production ownership audit remains open. |

| 2026-10-24 | Follow-up undo-feedback warning stack and second test-isolation change | **Superseded by subsequent targeted run** | A run after `efd187ede07d5bdacd1f8b159029b0051a882bd0` still warned, with the stack through `dailySalahTrackingServiceProvider` read by `_syncDailySalahAfterUndo()`. This proved the first Qaza-service fake was insufficient. The next HomeController isolation and subsequent successful run are recorded below. |

| 2026-10-24 | Third undo-feedback warning stack and dashboard-test isolation | **Verified by subsequent targeted run** | The repeated warning came from `homeControllerProvider.invalidateDashboard()`, which invalidated `homeLocalDateProvider` and initialized the real PrayerTime/profile/database provider graph. Commit `3ce26e837a8ab4fe9d05d1b2f0b8dfc2228bccf7` overrides the HomeController in all three widget tests. The latest user-provided run after syncing through `2b152933` passed all 3 tests and emitted no Drift warning. This resolves this test path only; it does not clear production lifecycle warnings. |

| 2026-10-24 | Undo-feedback targeted rerun after HomeController isolation | **Passed: 3 tests; no Drift warning in captured output** | User ran `git fetch origin`, `git pull --ff-only origin tp-gen/separate-google-db` (fast-forward `e51975c6..2b152933`), then `flutter test --reporter expanded test/features/qaza/qaza_undo_feedback_widget_test.dart`. Output ended `00:05 +3: All tests passed!` and contains no Drift warning. Local `pubspec.lock` was not mentioned in this run; prior state showed it modified, so continue to preserve it. Regression fix is confined to test provider isolation; production DatabaseManager/Drift lifecycle audit remains open. |

| 2026-10-24 | Startup control-database constructor sequencing audit | **Reviewed; no overlapping startup open shown** | Inspected `lib/main.dart` and `loadInitialHomePrayerSelection()` in `lib/app/providers.dart`. Startup awaits `_initializeDatabase()` (whose temporary manager closes in `finally`), then awaits `loadInitialHomePrayerSelection()` (which also closes its temporary manager in `finally`), and only then calls `runApp()`. This normal startup path therefore does not show these two temporary control-database handles being live concurrently. Provider disposal still uses `unawaited(database.close())`; widget tests can trigger provider recreation before async close settles, which the targeted widget-test isolation addressed. The remaining manager/Stage 4 warnings still need stack-level confirmation. |

| 2026-10-24 | Database manager + Stage 4 warning audit | **Passed: 19 tests; warnings explained by multiple distinct handles in the test scenarios** | User ran `flutter test --reporter expanded test/data/local/database/database_manager_test.dart test/data/local/database/database_manager_stage4_test.dart`; output ended `00:18 +19: All tests passed!`. `AppDatabase` warning stack comes from `_verifySafetyCopy()`: it opens the safety-copy file with a new `NativeDatabase(copyFile)` while the control handle remains open, so these are separate file/executor handles. `GoogleWorkspaceDatabase` warnings occur as Stage 4 migration keeps previously migrated workspace handles cached while creating a different workspace's staging/published file; the code closes the staging handle before renaming and opening the published file. The test factory opens each `fileName` via `NativeDatabase(File('${directory.path}/$fileName'))`. Drift's warning counts open instances by runtime type, not by path or executor, so these logged warning sites are not evidence of shared-executor misuse by themselves. No production code changed in this audit. Keep the warning investigation open only for explicit same-file duplication / teardown evidence; do not silence it globally. |

| 2026-10-24 | Post-warning same-file lifecycle audit | **Core per-workspace dedup covered; close-during-open remains untested** | Read `DatabaseManager.databaseForWorkspace()` and `test/.../database_manager_stage4_test.dart`. The §8 test proves repeated and concurrent requests for one registered workspace return the same cached handle; the two-account test proves separate handles and isolated records. The Stage 4 migration opens staging files with a distinct `.migration-staging` suffix, awaits `staging.close()` before rename, then opens the published filename; the safety-copy verifier uses `NativeDatabase(copyFile)` on the copy. These code paths explain the logged type-level Drift warnings without proving shared executors. A separate potential lifecycle gap remains: `DatabaseManager.close()` currently snapshots cached handles and clears `_openingWorkspaceDatabases` / `_provisioningGoogleWorkspaces` without awaiting their in-flight futures. If close races an unfinished open/provisioning operation, a handle may finish after the close snapshot and be cached after close. This is a source-level risk hypothesis, not a reproduced failure. Next add a deterministic close-during-open regression test and fix ownership sequencing before declaring manager lifecycle accepted. |

| 2026-10-24 | Deterministic manager close/open race coverage and fix | **Targeted verification passed locally** | `lib/data/local/database/database_manager.dart` makes close idempotent, gates new open/provision requests, tracks in-flight initialization/startup migration, drains active open/provision futures before collecting handles, and closes handles created by those operations. `test/data/local/database/database_manager_stage4_test.dart` adds deterministic completer-gated tests for `close()` racing `databaseForWorkspace()` and `ensureGoogleWorkspace()`. User's local `dart format` reported `Formatted 2 files (0 changed)`. `flutter test --reporter expanded test/data/local/database/database_manager_stage4_test.dart` ended `00:23 +14: All tests passed!`; combined `database_manager_test.dart` plus Stage 4 ended `00:23 +21: All tests passed!`. Drift warnings remain; do not suppress them merely because these tests pass. Commits include `532b0de8` (close drain), `9369ffab` (race tests), `d3944110` (track active init/migration), `477d320f` (explicit callback typing). Full suite and static analysis after this change remain pending. |

| 2026-10-24 | Close-during-open/provision regression rerun | **Passed: 14 Stage 4 tests; 21 combined manager tests** | User ran `dart format lib/data/local/database/database_manager.dart test/data/local/database/database_manager_stage4_test.dart` (`Formatted 2 files (0 changed)`), then the Stage 4 file alone (`00:23 +14: All tests passed!`) and both manager files together (`00:23 +21: All tests passed!`). Drift multiple-instance warnings still appear on migration/safety-copy test paths. Results verify these targeted tests only; the full test suite, `flutter analyze`, and Android build have not been rerun after this lifecycle change. Preserve the modified `pubspec.lock`; no lockfile operation was part of this test run. |

| 2026-10-24 | Adoption publication racing manager close | **Passed locally: 15 Stage 4 tests; 22 combined manager tests** | User's test log shows the publication/close completer test ran (`+16`) and Stage 4 ended `00:25 +15: All tests passed!`; the combined manager run ended `00:20 +22: All tests passed!`. These tests confirm manager close waits for publication and closes the resulting published handle. Drift warnings remain visible during tests and are still not globally suppressed. |

| 2026-10-24 | Flutter analysis baseline after manager lifecycle changes | **0 errors; 4 warnings; 27 info** | User ran `flutter analyze` in the synchronized checkout: `31 issues found` in 11.9 seconds. Warnings: unnecessary `!` at `local_backup_service.dart:2385`; unused `_selectMaps` at `local_backup_service.dart:3363`; unnecessary `!` at `app_database.dart:104`; unused manager forwarding method `_migrateLegacyGoogleWorkspace` at `database_manager.dart:235`. The package `uuid` is imported directly by `account_local_store.dart` but was not declared in `pubspec.yaml`. Follow-up commits remove the two redundant assertions and two unused private helpers and declare `uuid: ^4.6.0`; all are pending a local analyzer rerun. Remaining infos are mostly style notices plus three async-`BuildContext` lints in `qaza_undo_feedback.dart` that should be reviewed separately rather than mass-fixed without tests. |

### Checkpoint update template

For every meaningful progress update, append:

- **Date / stage**
- **What changed** (exact files and commit SHA if committed)
- **Evidence** (commands run, exact test totals, build/CI/device scope)
- **Result** (pass/fail/blocked; separate old failures from new)
- **Open risks / decisions**
- **Next action and gate**

Do not mark a stage complete until its acceptance gate has evidence. If no code was changed, say so explicitly.

---

## 5. Immediate next action

The user-provided full-suite output ends `02:58 +800: All tests passed!` after test-helper optimization `72700e14`. Static analysis has 0 errors, 4 warnings, and 26 info. Initial Drift audit: `appDatabaseProvider` creates one `AppDatabase.control()`, and `databaseManagerProvider` is explicitly injected with that same object; `qazaLocalStoreProvider` resolves through that manager. `loadInitialHomePrayerSelection()` also creates a standalone `DatabaseManager()` and awaits close, but the warning's same-executor condition means this is not yet a proven cause. The latest user-provided run after syncing through `2b152933` passed `qaza_undo_feedback_widget_test.dart` (3 tests) without a Drift warning. The HomeController fake isolates the UI test from unrelated refresh providers; treat this as a test-path resolution only. The latest user run of the database-manager and Stage 4 files ended `00:18 +19: All tests passed!`. The warning stacks are now mapped to multiple distinct file-backed handles in the test scenarios: `_verifySafetyCopy()` opens a distinct safety-copy file, and startup migration intentionally holds already-published per-account databases while creating other account staging/published files. This is compatible with TP-GEN's one-file-per-account design; Drift's type-level counter does not identify executor or file equality. Do not suppress the warning or change production code merely to silence it. The close/open/provision and adoption-publication race tests were run locally and passed (15 Stage 4 tests, 22 combined manager tests). The user then ran `flutter analyze` and reported 0 errors, 4 warnings, and 27 infos. Four warning-level findings and the undeclared direct `uuid` dependency have follow-up fixes committed; those newer commits need local formatting/analyzer verification. Review the three async-`BuildContext` notices and remaining style infos separately. Next sync the branch, preserve `pubspec.lock`, run `flutter test --reporter expanded test/data/local/database/database_manager_stage4_test.dart`, then run both manager test files together. Review the actual result before considering the race fixed. Also run `dart format --output=none --set-exit-if-changed lib/data/local/database/database_manager.dart test/data/local/database/database_manager_stage4_test.dart` and `flutter analyze` after any fixes. The warning stacks appear consistent with separate intended file-backed handles; they did not establish shared-executor misuse. The production account-isolation/recovery audit, full-suite rerun after latest changes, Android build and device/cloud checks remain open. Review the settings-screen hit-test warning and then complete account-isolation, recovery/migration, device-verification, formatter/final-diff, and lockfile-review gates. Do not suppress Drift warnings or declare TP-GEN acceptance/merge readiness solely because tests pass.

The full suite has now passed 800 tests. The next work is to investigate the Drift multiple-database warnings and validate the account-isolation/recovery architecture. Start by reviewing the exact local state without changing the lockfile:

```powershell
git status --short --branch
git log -5 --oneline
```

After the targeted rerun, continue the production ownership audit across `app/providers.dart`, `app_database.dart`, and `database_manager.dart`, especially startup's standalone `loadInitialHomePrayerSelection()` manager and remaining manager-test warnings. The warning counter alone is not evidence that two instances share one executor. Do not set `dontWarnAboutMultipleDatabases = true` as a shortcut. Record evidence and tests for the fix before acceptance.

Keep `pubspec.lock` modified exactly as it is unless its diff is reviewed; do not reset it as part of syncing or test cleanup. If the full suite fails, capture each remaining failure and fix the underlying cause, then rerun the affected tests and full suite. Update this tracker after each meaningful result. Do not build a release APK or declare the branch ready for merge while the full-suite, static-analysis, Drift lifecycle, and architecture gates remain unresolved.

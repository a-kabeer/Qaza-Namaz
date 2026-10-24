# TP-GEN Progress Tracker — Separate Encrypted Local Database per Google Account

**Last updated:** 2026-10-24 (Asia/Karachi) — latest full test suite passed 804 tests after the chained-account journey test fix; analyzer checkpoint has 0 errors/warnings and 23 info findings. Device/Drive timing and architecture gates remain open.  
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
| Branch synchronization | **Synced at latest diagnostic checkpoint** | User's PowerShell output confirms fast-forward from `746ed58d` to `9254e45c` on `tp-gen/separate-google-db`; `git pull --ff-only` succeeded and local branch matched `origin/tp-gen/separate-google-db`. |
| Local working-tree safety | **Preserve local changes** | Two stashes remain preserved: `preserve local formatting before TP-GEN sync` and `preserve pubspec.lock before signout test fix`. After sync, `dart format` changed `cloud_setup_choice_screen.dart`, `sync_engine.dart`, and `account_screen_test.dart`; `flutter pub get` also modified `pubspec.lock`. Its diff shows lock metadata/order changes and `uuid` changing from transitive to direct. Keep the edits/stashes until the manifest and full diff are reviewed; do not reset or drop stashes. |
| Database manager test teardown | **Targeted tests passed** | User ran `flutter test test/data/local/database/database_manager_test.dart test/data/local/database/database_manager_stage4_test.dart`; output ended `All tests passed!`. Drift duplicate-database warnings appeared and remain to be investigated. |
| Qaza screen contract tests | **Passed** | User ran `flutter test test/features/qaza/qaza_tracker_screen_contract_test.dart`; output ended `+53: All tests passed!`. Windows/Unix line-ending normalization is present in the test file on GitHub. |
| Full test suite | **Latest rerun passed: 804 tests** | User's latest `flutter test --reporter expanded` output ends `02:46 +804: All tests passed!`. This is after the bounded-pump fix for the chained account journeys. The previous 802-pass/2-timeout result is superseded; both scenarios were also rerun individually and the complete chained-journey file passed all 3 scenarios. Non-fatal FlexColorScheme warnings and Settings-language test hit-test warnings remain visible for follow-up; the import-controller test also deliberately logs its injected first-attempt failure while testing retry behavior. |
| Static analysis | **Latest diagnostic checkpoint: 0 errors, 0 warnings, 23 info** | User ran `flutter analyze` after the latest branch sync and formatter/test runs; output ended `23 issues found (ran in 109.1s)`. These are `info` lints only, including style cleanup and deprecated Radio API notices. The latest run did not report errors or warnings. Earlier analyzer results in the history table remain historical; this latest result does not replace the need to review unused migration/helper code and direct dependency ownership during the architecture audit. |
| Database/account architecture | **Close-race and undo-context targeted tests passed; architecture not yet accepted** | The manager test logs passed with 15 Stage 4 tests and 22 combined manager tests. The latest `flutter analyze` ends `23 issues found (ran in 13.9s)` with zero errors and zero warnings; the three `use_build_context_synchronously` notices are gone after the provider-container capture change. `qaza_undo_feedback_widget_test.dart` ended `00:05 +3: All tests passed!`. Drift multiple-instance warnings remain visible in manager/migration tests and are not proof of shared-executor reuse by themselves. Full suite, build and broader architecture gates remain open. |
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

- [ ] Re-run the full test suite against the latest UX diagnostic and sign-out test-fix commits. A prior full suite passed 803 tests; that result predates the current diagnostic changes. Review remaining warnings rather than suppressing them.
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

| 2026-10-24 | Flutter analysis rerun after cleanup | **0 errors; 0 warnings; 26 info** | User ran `flutter analyze` after syncing and running `flutter pub get`: final output `26 issues found` in 21.1 seconds. The previous four warnings and `uuid` direct-dependency notice disappeared; 26 informational style/deprecation notices remain. Three `use_build_context_synchronously` notices remain in `qaza_undo_feedback.dart:233, 325, 381`; code review shows each call only needs the `ProviderContainer` to run Daily Salah reconciliation after an awaited undo. Proposed fix: capture the container before the async gap and pass it directly rather than resolving it from a `BuildContext` afterward, preserving the sync even if the undo sheet closes. |

| 2026-10-24 | Analyzer and focused test results after cleanup commits | **Passed: 0 errors/warnings; 15 Stage 4 tests; 22 combined manager tests** | User's analyzer output ends `26 issues found (ran in 21.1s)` with zero warnings and zero errors. The separate uploaded test logs show Stage 4 `00:23 +15: All tests passed!` and the two manager files together `00:29 +22: All tests passed!`. Drift warning messages continue during tests at safety-copy and distinct staging/published workspace constructors; they remain visible and must not be suppressed globally. Local `flutter pub get` resolved dependencies; preserve and review the local `pubspec.lock` diff because the direct `uuid` declaration changes dependency intent. Full suite and Android build after these changes are still pending. |

| 2026-10-24 | Remove async BuildContext use from Daily Salah undo reconciliation | **Verified: 0 async-context notices; 3 widget tests passed** | Commit `a1847dc1` captures `ProviderContainer` before awaited undo operations and passes it through to the background Daily Salah reconciliation helper. User's latest `flutter analyze` now shows 23 info notices and no warnings/errors, with all three `use_build_context_synchronously` notices absent. `flutter test --reporter expanded test/features/qaza/qaza_undo_feedback_widget_test.dart` ended `00:05 +3: All tests passed!`. Full suite after this change remains pending. |

| 2026-10-24 | Full-suite rerun after lifecycle and undo-context changes | **Passed: 803 tests (~2m53s)** | Latest user-provided `flutter test --reporter expanded` log ends `02:53 +803: All tests passed!`. Includes test coverage for close racing workspace open, Google workspace provisioning, and adoption publication, plus the updated undo feedback flow. There are no failing tests in the output. Remaining non-fatal warnings include hit-test warnings from `settings_screen_test.dart` language taps, FlexColorScheme missing `primaryLightRef`/`secondaryLightRef`/`tertiaryLightRef` messages, Drift multiple-instance warnings from test migration/safety-copy/staging constructors, and intentional failure-path diagnostics emitted by the import-controller retry test. Next: inspect the settings test scroll/tap helper and theme reference setup; preserve the Drift warning analysis without disabling warnings; check the final `pubspec.lock` diff; run Android release build and required device/cloud acceptance checks. |

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

The user-provided full-suite output ends `02:58 +800: All tests passed!` after test-helper optimization `72700e14`. The latest `flutter analyze` has 0 errors, 0 warnings, and 26 info. Initial Drift audit: `appDatabaseProvider` creates one `AppDatabase.control()`, and `databaseManagerProvider` is explicitly injected with that same object; `qazaLocalStoreProvider` resolves through that manager. `loadInitialHomePrayerSelection()` also creates a standalone `DatabaseManager()` and awaits close, but the warning's same-executor condition means this is not yet a proven cause. The latest user-provided run after syncing through `2b152933` passed `qaza_undo_feedback_widget_test.dart` (3 tests) without a Drift warning. The HomeController fake isolates the UI test from unrelated refresh providers; treat this as a test-path resolution only. The latest user run of the database-manager and Stage 4 files ended `00:18 +19: All tests passed!`. The warning stacks are now mapped to multiple distinct file-backed handles in the test scenarios: `_verifySafetyCopy()` opens a distinct safety-copy file, and startup migration intentionally holds already-published per-account databases while creating other account staging/published files. This is compatible with TP-GEN's one-file-per-account design; Drift's type-level counter does not identify executor or file equality. Do not suppress the warning or change production code merely to silence it. The close/open/provision and adoption-publication race tests passed locally (15 Stage 4 tests, 22 combined manager tests). The user reran `flutter analyze` after syncing dependencies: 0 errors, 0 warnings, 23 info notices. The three async-`BuildContext` notices were removed by commit `a1847dc1`, and the Qaza undo feedback widget test passed all 3 tests. The latest full `flutter test --reporter expanded` run passed 803 tests (`02:53 +803: All tests passed!`). No test failures appear in the provided output. Remaining warning cleanup, final lockfile diff, Android build, and architecture/device checks are the next gates. Next sync the branch, preserve `pubspec.lock`, run `flutter test --reporter expanded test/data/local/database/database_manager_stage4_test.dart`, then run both manager test files together. Review the actual result before considering the race fixed. Also run `dart format --output=none --set-exit-if-changed lib/data/local/database/database_manager.dart test/data/local/database/database_manager_stage4_test.dart` and `flutter analyze` after any fixes. The warning stacks appear consistent with separate intended file-backed handles; they did not establish shared-executor misuse. The production account-isolation/recovery audit, full-suite rerun after latest changes, Android build and device/cloud checks remain open. Review the settings-screen hit-test warning and then complete account-isolation, recovery/migration, device-verification, formatter/final-diff, and lockfile-review gates. Do not suppress Drift warnings or declare TP-GEN acceptance/merge readiness solely because tests pass.

The full suite has now passed 800 tests. The next work is to investigate the Drift multiple-database warnings and validate the account-isolation/recovery architecture. Start by reviewing the exact local state without changing the lockfile:

```powershell
git status --short --branch
git log -5 --oneline
```

After the targeted rerun, continue the production ownership audit across `app/providers.dart`, `app_database.dart`, and `database_manager.dart`, especially startup's standalone `loadInitialHomePrayerSelection()` manager and remaining manager-test warnings. The warning counter alone is not evidence that two instances share one executor. Do not set `dontWarnAboutMultipleDatabases = true` as a shortcut. Record evidence and tests for the fix before acceptance.

Keep `pubspec.lock` modified exactly as it is unless its diff is reviewed; do not reset it as part of syncing or test cleanup. If the full suite fails, capture each remaining failure and fix the underlying cause, then rerun the affected tests and full suite. Update this tracker after each meaningful result. Do not build a release APK or declare the branch ready for merge while the full-suite, static-analysis, Drift lifecycle, and architecture gates remain unresolved.


---

## 6. Newly reported device issue — account-specific Google connection failure

**Reported:** 2026-10-24 (Asia/Karachi)  
**Device evidence:** Screenshot from the startup account-choice screen. Sign-in succeeded for `akalbaloshi0@gmail.com`; trying `a.kabeer1991@gmail.com` showed the generic dialog “Something Went Wrong — Google connection could not be completed. Try again or continue locally.” The dialog offered Cancel and Retry.

**Status: Open — root cause not yet identified. Do not reset account/workspace data.**

### Source-path review

- `lib/features/onboarding/cloud_setup_choice_screen.dart` runs `cloudAccountProvider.signIn()`, then activates the verified account workspace, then performs Google Drive backup discovery. Its catch path sends an exception to `_showFailure`; unknown/retryable errors may be presented as a generic connection failure. Therefore the screenshot does not prove that the native Google account picker itself failed.
- `packages/qaza_cloud_adapter/lib/src/google_cloud_providers.dart` `_signIn()` performs Google authentication, Drive authorization, profile persistence, cloud-sync enablement and scheduler setup within one try/catch. Each stage can be the failure source.
- Workspace activation and database resolution happen after account authentication, so a missing/invalid legacy workspace state for the second stable Google ID remains another possibility.
- The UI currently collapses multiple failure sources into similar wording. A real exception/code and stage are required before choosing a fix.

### Diagnostic plan

- [ ] Reproduce the failure once with `a.kabeer1991@gmail.com` and collect the exception/code from Android logcat for the same timestamp.
- [ ] Determine whether failure happens during `GoogleSignIn.authenticate()`, Drive authorization, cloud-state/profile persistence, workspace activation/database open, or Drive backup discovery.
- [ ] Check Google Cloud OAuth consent-screen publishing/testing status and tester list if the captured error is an OAuth access/consent denial. Do not alter OAuth settings based only on the generic dialog.
- [ ] Add stage-specific, privacy-safe diagnostics and regression tests if current logging cannot identify the failing step. Never log access/refresh tokens or raw local database contents.
- [ ] Once the failing stage is established, fix and test that path, update this tracker, and repeat the real-device attempt.

**Safety:** Do not delete either Google account, Drive backups, local databases, encryption keys, or app data to troubleshoot this. The fact that one account works and the other fails is a clue, not proof of an OAuth allowlist or database defect.


### Diagnostic update — first Android logcat sample

**Date:** 2026-10-24  
**Result:** **Inconclusive; no root cause established.**

Lines supplied by the user around 13:12 show:
- `GoogleSignInActivity` from Google Play services was launched.
- `WindowLayout` logged a zero requested height for that activity. This alone is not an authentication error and does not identify why the sign-in flow failed.
- `payjoy_access_service` and `PantaCard.SysUi.PluginFileUtils` messages appear to be device/OEM or third-party service noise, not a demonstrated Qaza Namaz failure.

No explicit Google Sign-In exception, OAuth error code, credential error, package/configuration error, or app exception is present in the supplied excerpt. Account-specific OAuth restrictions, Drive authorization failure, and post-auth workspace/storage failure therefore remain hypotheses only.

**Next evidence required:** clear logcat, reproduce just the failed attempt, capture the fresh logcat output including non-error/warning lines, and inspect messages near the attempt across Google Sign-In/Play services and the app process. Redact access tokens, secrets and personal data before sharing. Do not reset application data, remove accounts, or delete local/Drive backups as a diagnostic shortcut.


### Follow-up clarification — screen recording account selection

The user confirmed that they tapped the account which was already displayed as connected before the chooser opened. Therefore the recording does **not** establish an account-switch mismatch. The observed long backup validation/restore remains worth diagnosing, but should be treated separately from the sign-in failure reported for the other test account.

Updated next action: reproduce the failing account sign-in and capture the Android logcat exception. Do not infer the root cause from the generic UI message; do not reset data or delete backups.


---

## 7. Re-review of screen recording — sign-out, loading, and blank-screen behavior

**Reviewed:** 2026-10-24  
**Recording:** `screen-20261024-132807.mp4` (79.25 seconds)  
**User clarification:** The “Something went wrong” Google-connection issue is fixed. In this recording, the user selected `akalbaloshi0@gmail.com`. The recording begins with `a.kabeer1991@gmail.com` shown on the Account page, so the later switch to `akalbaloshi0@gmail.com` is expected. Do not treat the account-name change as evidence of cross-account data leakage.

### Observed timeline

| Approx. time | Visible behavior | Assessment |
|---|---|---|
| 0–5.8 s | Home screen; Qaza total is 9,000. | Baseline UI. |
| 5.8–6.8 s | Account page shows `a.kabeer1991@gmail.com` and a Sign out action. | Previous account was active. |
| 6.8–7.9 s | After Sign out, the app returns to the Welcome/account-choice screen. | This first sign-out navigation takes about 1 second; no sustained blank screen is visible in this segment. |
| About 9–18 s | After Google sign-in is initiated, the page displays “Connecting to Google Drive” / checking for an existing backup; the buttons are unavailable while work is in progress. | Roughly 9 seconds of blocking connection/backup discovery before the next decision. |
| About 18–23 s | A “Replace local progress?” confirmation is shown, followed by “Different changes found.” | Restore/replace is a consequential choice and must stay explicit. |
| About 23–62 s | The UI stays on “Restoring your verified backup…” with a progress indicator for roughly 35–40 seconds. | Significant wait. The current UI does not make the expensive sub-stage or stall reason obvious in the recording. The video alone cannot tell whether time is spent downloading, validating, applying SQL changes, or refreshing providers. |
| About 63 s | Home appears with total Qaza reduced from 9,000 to 8,640 (34 completed, 8,606 pending). | Consistent with the user-confirmed remote restore/replace choice; not evidence of an accidental account mismatch. |
| About 67–69.3 s | User opens Settings → Account; the account screen briefly checks identity, then displays `akalbaloshi0@gmail.com`. A Sign out control is visible. | Account display matches the account the user says they selected. |
| About 69.4–79.2 s | The recording becomes a uniform grey/blank frame until the clip ends. | **Open, high priority to reproduce.** This occurs immediately after the account page is shown and may correspond to the reported blank/white screen around sign-out, but the frames alone cannot prove the exact tap or distinguish an app-rendering failure from a capture/lifecycle artifact. No status or navigation bars are visible on the grey frames. |

### Source-code path reviewed

- `lib/features/account/account_screen.dart::_disconnect()` first queries sync status. When pending changes exist, it may discover the remote backup, run `backupNow()`, and prompt before sign-out. This can intentionally delay sign-out to protect unsynced data; the screen should communicate that work clearly.
- `_finishSignOut()` awaits cloud disconnect, activates a safe Guest/local workspace, invalidates account-scoped providers, persists the returning-account-choice marker, and then navigates to `StartupGate`. A failure or hang in these sequential operations is a candidate for instrumentation.
- `lib/features/onboarding/cloud_setup_choice_screen.dart::_connectGoogle()` performs sign-in, activates the Google workspace, and then discovers the Drive backup. `_restoreBackup()` awaits `cloudSync.resolveConflict(... useRemote ...)` while setting the restore progress UI. The actual 35–40 second cost must be timed by sub-stage before optimizing it.
- `CloudSetupChoiceScreen.initState()` also kicks off `_restoreExistingAccount()`. Check this lifecycle in sign-out/returning-choice tests so stale restore work cannot race with a new explicit account choice.

### Required follow-up

- [ ] Add privacy-safe stopwatch/diagnostic events to measure sign-out stages separately: sync status check; pending-change decision/discovery/backup; cloud disconnect/scheduler cancellation; Guest/local workspace activation; control-database marker write; final navigation.
- [ ] Add matching restore timings for authentication and Drive authorization, backup discovery/download, envelope/schema/hash validation, database import/migration, post-restore session refresh, and route completion. Never log tokens, raw backup contents, or unnecessary personal data.
- [ ] Reproduce the grey/blank screen with fresh logcat captured from before tapping Sign out until after the expected account-choice screen should render. Record the precise tap and whether Android system bars remain visible.
- [ ] Add widget/regression tests for signing out after a successful Google restore and for sign-out with pending changes. Assert that navigation reaches a visible, retryable screen, the old account is not active, and local records remain intact.
- [ ] Run a representative large-backup restore with stage timings. Optimize the measured bottleneck; do not simply shorten/remove integrity checks or hide the progress indicator.
- [ ] Keep the initial account-choice screen responsive. Where network work must continue, show the exact stage and an appropriate recoverable state; never leave the user with an unexplained blank surface.

**Current decision:** the Google sign-in error is reported fixed. The confirmed UX findings to work next are the long connection/backup-discovery delay, the roughly 35–40 second restore wait, and the blank/grey screen at the end of the recording. Root cause for the blank screen and restore duration is not yet established.

### Correction to the previous account-switch hypothesis

The account change in the recording is now explained by the user's clarification: the starting Account page shows `a.kabeer1991@gmail.com`, then the user selects `akalbaloshi0@gmail.com`, and the final Account page shows `akalbaloshi0@gmail.com`. The video does not establish an account-identity mismatch. Close that hypothesis unless new evidence contradicts it.

### Account-specific “Something went wrong” message — status update

The user explicitly reports that this issue is fixed. Mark the original sign-in error as **resolved by user-reported reproduction**, with no code-root-cause claim. Do not keep requesting logcat for that resolved symptom unless it returns. The loading/blank-screen items above remain separate open issues.


---

## 8. UX diagnostic implementation checkpoint — timings and visible sign-out progress

**Date:** 2026-10-24  
**Status:** Code committed; automated verification and physical-device reproduction still pending.

### Changes committed on `tp-gen/separate-google-db`

- Added `lib/core/diagnostics/flow_timing.dart` (`b6cb9b42`): a debug-only asynchronous stage timer. It logs constant flow/stage labels, outcome, and elapsed milliseconds; it does not log account identifiers, emails, Qaza records/counts, backup contents, or authorization tokens.
- Updated `lib/features/account/account_screen.dart` (`12dec995`, `6c04b4b6`, `d808def5`): account restore/profile and sync-status refresh timings; interactive Google sign-in and workspace activation timings; sign-out timings for sync status, Drive discovery, backup attempt, cloud disconnect/scheduled-work cancellation, workspace activation, and the returning-choice marker. Sign-out failures are sent through the existing redacting diagnostics service. Added a visible indeterminate progress panel while account connection/backup checking/sign-out work is in progress.
- Updated `lib/features/onboarding/cloud_setup_choice_screen.dart` (`eeb40ae5`, `9fe2c8af`): timing around startup/interactive Google connection, workspace activation, backup discovery, and confirmed remote restore. A follow-up correction explicitly retains workspace activation after sign-in.
- Updated `lib/app/providers.dart` (`0f7ea716`): timing for startup Google-account restoration and restoration of its local workspace.
- Updated `packages/qaza_cloud_adapter/lib/src/sync_engine.dart` (`76943a64`): timing for remote backup revalidation, local recovery snapshot export/write/read-back verification, remote restore application into the database, and sync-cursor persistence.
- Updated `test/features/account/account_screen_test.dart` (`f11cd977`): added a regression test that holds sync status unresolved and asserts the sign-out progress card stays visible until the operation completes.

### Verification status

- [ ] Run `dart format` on all changed Dart files.
- [ ] Run the targeted account-screen test, especially `sign out shows a visible progress state while checking backup status`.
- [ ] Run the account-screen and cloud setup choice test files.
- [ ] Run the full unit/widget test suite and static analysis on the synchronized local branch.
- [ ] Build/run a **debug** APK, reproduce the sign-out / long restore flow, and capture `[tp-gen-timing]` messages from Logcat. These timings are necessary to identify the true bottleneck.
- [ ] Reproduce the final uniform grey screen with a recording that includes the exact tap and Logcat from before sign-out until after navigation.

### Important caveats

- These commits have not yet been executed in the user's local checkout in this checkpoint. Passing tests or a successful build must not be claimed until the user or CI provides that evidence.
- The recording's uniform grey final frames alone do not prove a Flutter rendering crash; this remains a device-side issue to reproduce.
- A plausible performance hypothesis is that backup payload validation/re-download may contribute to the delay. It remains a hypothesis until stage timings confirm it. Do not remove the post-recovery remote freshness check, backup validation, or recovery snapshot verification just to shorten the operation.
- Preserve local `pubspec.lock` changes; do not reset the branch or delete local/Drive test data as part of this work.

**Next action:** synchronize these commits locally, run formatting and the focused account-screen/cloud-setup tests, and reproduce the UX on a debug build. Use the emitted stage timings to decide whether an optimization is justified, then update this tracker with exact results.


### Follow-up instrumentation refinement

- Added `f9d00a9e` in `packages/qaza_cloud_adapter/lib/src/sync_engine.dart`: the post-recovery-snapshot remote backup recheck now has its own timing event, `cloud_restore.recheck_remote_backup_after_recovery_snapshot`. This distinguishes that operation from the initial `revalidate_remote_backup` stage.
- This is measurement only: the second freshness check and all recovery/validation behavior remain intact.
- Automated tests, formatting, and the real-device timings remain **pending**.


### Test feedback after syncing UX diagnostics — account-screen suite

**Evidence supplied by user:** `flutter test test/features/account/account_screen_test.dart` on the local Windows checkout.

- **Result:** 18 tests passed and 2 failed; both failures are `pumpAndSettle timed out` in the existing tests `offline sign-out cancellation preserves the connected session and local Qaza` and `offline sign-out anyway disconnects but keeps local Qaza records`.
- **Cause:** The sign-out flow now intentionally renders an indeterminate `CircularProgressIndicator` / `LinearProgressIndicator` while awaiting sync status and the offline safety dialog. Flutter's `pumpAndSettle()` waits for all animations to stop, so it is the wrong test wait condition in these two tests. This output does not show an app assertion or data-integrity failure in those two cases; it shows the test harness timeout before it can continue.
- **Positive evidence:** The newly added test `sign out shows a visible progress state while checking backup status` passed (`+14`), and the reachable-Drive sign-out test also passed. Recorded mocked test timings are fast and do not measure real Drive restore performance.

**Fix committed:** `10193e50` (`test(account): wait for sign-out dialog during progress animation`). The two offline tests now wait for the expected `Changes not backed up` dialog using bounded frame pumps rather than `pumpAndSettle()`. This preserves the real progress animation and tests the visible safety dialog.

**Verification status:** The adjustment is committed remotely but has **not yet been rerun locally or confirmed by CI**. Re-sync the branch and rerun the account screen test before treating this as resolved. Do not alter production animation behavior just to make `pumpAndSettle()` succeed.

**Next test sequence after syncing:**
1. `dart format lib/app/providers.dart lib/core/diagnostics/flow_timing.dart lib/features/account/account_screen.dart lib/features/onboarding/cloud_setup_choice_screen.dart packages/qaza_cloud_adapter/lib/src/sync_engine.dart test/features/account/account_screen_test.dart`
2. `flutter test test/features/account/account_screen_test.dart`
3. `flutter test test/features/onboarding/cloud_setup_choice_screen_test.dart`
4. `flutter analyze`

Then run a debug build on the phone and capture `[tp-gen-timing]` logs while reproducing sign-out/restore. These unit-test timings are not evidence of real Drive performance. The final grey-screen root cause remains open until reproduced with device logs.


### Latest local verification checkpoint — account and onboarding diagnostics

**Date:** 2026-10-24 (Asia/Karachi)  
**Branch:** `tp-gen/separate-google-db` at `9254e45c`, synced with origin before local formatting and dependency resolution.

**Results provided by the user:**
- `flutter test test/features/account/account_screen_test.dart` — **passed, 22 tests**. This verifies the previous two offline sign-out tests now find the expected safety dialog while the indeterminate progress animation is active.
- `flutter test test/features/onboarding/cloud_setup_choice_screen_test.dart` — **passed, 8 tests**, including Guest-to-Google adoption, Start Fresh keeping the saved Guest untouched, workspace activation, and repeated Connect taps.
- `flutter analyze` — completed in 109.1 seconds with **23 info-level findings, no errors, and no warnings**. Informational findings include dangling library documentation, curly-brace/style suggestions, unnecessary imports/interpolation braces, possible super parameters, and deprecated `Radio` API usage. These findings are not test failures; review them according to scope rather than broad cleanup during this diagnosis.

**Local change safety:**
- After sync, `dart format` reported formatting changes in `lib/features/onboarding/cloud_setup_choice_screen.dart`, `packages/qaza_cloud_adapter/lib/src/sync_engine.dart`, and `test/features/account/account_screen_test.dart`.
- Flutter dependency resolution modified `pubspec.lock`. The observed diff reorders the `flutter_localizations` entry, adds a SHA-256 to the `flutter_native_oss_licenses` entry, and changes `uuid` from transitive to direct dependency. Before committing, inspect `pubspec.yaml` and the complete diff to establish whether the lockfile change is required by the manifest and current dependency graph.
- The user preserved two stashes: `preserve local formatting before TP-GEN sync` and `preserve pubspec.lock before signout test fix`. Do not pop/drop either stash until all diff checks are complete.

**Interpretation / open gates:**
- The two targeted test files provide **30 passing tests**, but this is not a replacement for the full-suite rerun on the latest diagnostic code.
- Test/mock timing events do not establish real Google Drive latency. Physical-device restore/sign-out stage timings and the final grey/blank screen reproduction remain pending.
- Next recommended gate: review the complete diff and dependency manifest, then run the full test suite on the latest branch. After that, continue the architecture/isolation audit, debug APK/device checks, and update this tracker with exact outcomes.


### Latest full-suite checkpoint — two account journey failures

**Date:** 2026-10-24 (Asia/Karachi)  
**Command:** `flutter test --reporter expanded`  
**Observed result:** **802 passed, 2 failed**, around 3:05 elapsed.

Failing tests:
1. `scenario 5 Case B: found backup reconciles the existing local Google workspace via Keep Local and leaves the Guest workspace untouched`
2. `scenario 9: offline changes survive an A -> B -> A account round trip and are uploaded when A is reactivated`

Both are account-workspace and sync-lifecycle invariants. Do not weaken tests, skip either scenario, or delete/merge workspace data to make the suite green.

**Evidence limitation:** the user-provided output contains the final failed-test names but begins in the middle of a Flutter stack trace; the actual first exception/expectation mismatch and its adjacent assertion context are missing. No root cause is claimed yet.

**Next diagnostic step:** rerun only `test/features/account/account_chained_journeys_test.dart` and capture the complete failure detail (especially the first error, expected/actual values, and test line number). Fix the underlying behavior or test harness only after identifying which assertion fails, then rerun both scenarios, the targeted account/onboarding tests, and the full suite. Keep the existing local formatting and lockfile changes and both stashes preserved. The earlier 22 account-screen tests, 8 onboarding tests, and analyzer run (0 errors/warnings, 23 info findings) remain valid for their respective commands but do not override this full-suite failure.


### Follow-up — bounded pump fix for chained account journeys

**Date:** 2026-10-24 (Asia/Karachi)  
**Evidence:** isolated Scenario 5 run in the user's local checkout failed at line 94 with `pumpAndSettle timed out`. The trace shows Google sign-in and Google workspace activation completed; the test timed out while awaiting the conflict decision UI. The test uses an indeterminate progress panel during that wait, so `pumpAndSettle()` is not a valid wait condition.

**Test-only fix committed remotely:** `cad24b03ecf1ddc0f213a78204b5762d1ade057c` (`test(account): avoid settling indeterminate journey progress`). In `test/features/account/account_chained_journeys_test.dart`, added bounded pump helpers for waiting for a specific dialog, waiting for a progress panel to disappear, and waiting for the Welcome route after sign-out. Updated the affected waits in Scenario 5 and Scenario 9. Assertions and production code are unchanged; neither account data nor cloud safety behavior was modified.

**Verification status: pending.** The new test commit is on the remote branch but has not yet been pulled into the user's local checkout or run there. After safely syncing, run:
```powershell
dart format test/features/account/account_chained_journeys_test.dart
flutter test --reporter expanded --plain-name "scenario 5 Case B" test/features/account/account_chained_journeys_test.dart
flutter test --reporter expanded --plain-name "scenario 9" test/features/account/account_chained_journeys_test.dart
```
If either still fails, capture the first underlying exception/expectation mismatch and fix it without weakening account-isolation or data-preservation assertions. Only after both isolated journeys pass should the full suite be rerun.


### Targeted reruns after the chained-journey bounded-pump fix

**Date:** 2026-10-24 (Asia/Karachi)  
**Commit under test:** `cad24b03` (test-only bounded waits for the indeterminate account-operation progress UI).

User-provided local results:
- `flutter test --reporter expanded --plain-name "scenario 5 Case B" test/features/account/account_chained_journeys_test.dart` — **passed: 1 test** in about 7 seconds.
- `flutter test --reporter expanded --plain-name "scenario 9" test/features/account/account_chained_journeys_test.dart` — **passed: 1 test** in about 25 seconds.

The fixes avoid `pumpAndSettle()` while an indeterminate operation indicator is running, waiting instead for the expected dialog, route, or progress-panel disappearance. Production code and data-preservation/account-isolation assertions were not changed.

**Still pending:** run the entire `test/features/account/account_chained_journeys_test.dart` file, then rerun the full project suite on this updated code. The last full-suite run before this test-only fix reported 802 passing and 2 failures, both now individually passing in isolated reruns; this is not yet evidence that the entire suite passes. Flutter dependency resolution again printed `Changed 1 dependency!`; review local `pubspec.lock` status/diff and preserve all existing stashes.


### Full chained account journey file passes

**Date:** 2026-10-24 (Asia/Karachi)  
**Command:** `flutter test --reporter expanded test/features/account/account_chained_journeys_test.dart`  
**Result:** **Passed: all 3 tests** in about 7 seconds on the user's local Windows checkout.

Passing scenarios:
- Scenario 5 Case B — Keep Local reconciliation preserves the existing Google workspace and leaves the separate Guest workspace untouched.
- Scenario 6 — An existing Google workspace's unsynced changes are uploaded instead of being overwritten by a remote restore.
- Scenario 9 — Offline changes under Google A remain intact through sign-out, Google B activation, and return to Google A.

The bounded-pump test fix is therefore verified for the complete chained-journey file, not only isolated scenarios. The assertions for workspace/data preservation remain in place.

**Next gate:** preserve any new `pubspec.lock` change created by Flutter dependency resolution, then rerun the full suite against the updated branch. This file-level pass does not yet establish a full-suite pass or physical-device Google Drive verification.


### Full test suite passes after chained-journey test fix

**Date:** 2026-10-24 (Asia/Karachi)  
**Command:** `flutter test --reporter expanded`  
**Result supplied by user:** **804 tests passed; all tests passed**, final output `02:46 +804: All tests passed!`.

This run follows the test-only bounded-pump changes in `cad24b03`, and it supersedes the earlier full-suite result of 802 passed / 2 timed-out journey tests. In the meantime the user also verified:
- Scenario 5 Case B alone — passed.
- Scenario 9 alone — passed.
- The complete `test/features/account/account_chained_journeys_test.dart` file — all 3 scenarios passed.

**Warnings that remain visible but did not fail this test run:**
- FlexColorScheme warns that `primaryLightRef`, `secondaryLightRef` and `tertiaryLightRef` are null.
- Settings screen language-selection tests emit Flutter hit-test warnings for tap positions that may not hit the requested option.
- The profile Qaza apply retry test logs its intentionally injected first-attempt `StateError` while exercising recovery/retry.

These warnings should be reviewed deliberately; do not globally suppress them or confuse the expected injected retry log with a test failure.

**Acceptance remains open:** full-suite green is a significant milestone but does not establish physical-device Google Drive restore/sign-out timing, explain the final grey/blank screen in the recording, or complete the separate encrypted workspace architecture/isolation/recovery audit. Static-analysis checkpoint remains 0 errors, 0 warnings and 23 info-level findings from the latest user-provided analyzer run. Four local stashes are still being preserved; review the complete diffs and `pubspec.lock` before applying or dropping anything.


### TP-GEN — Sign-out concurrency and startup recovery

**Date:** 2026-10-24 (Asia/Karachi)  
**Status:** Implementation committed for local verification; device acceptance remains open.

**Audit findings from the current branch:**
- `_disconnect()` read `WidgetRef` inside its catch handler after asynchronous work. The sign-out flow navigates away from the account widget, so a later exception could trigger the secondary `Cannot use "ref" after the widget was disposed` error and hide the original failure.
- `activeLocalAccountIdStateProvider` duplicated `AccountSessionManager.activeLocalAccountId`. The session manager's listener callback wrote to a second Riverpod state provider synchronously before `ChangeNotifier` finished notifying listeners. This nested provider-graph update is a credible cause of the reported concurrent-modification exception; it is addressed by deriving `activeUserIdProvider` directly from the session manager's selected state.
- `_finishSignOut()` persisted `returningAccountChoicePending` only after activating Guest and invalidating several providers. The marker is now persisted before switching workspaces so an interrupted transition has a durable route back to account choice.

**Changes committed:**
- Removed the duplicated active-account state mirror; `AccountSessionManager` is now the single source of truth for the active workspace ID.
- Captured a `ProviderContainer` and diagnostics service before the first asynchronous gap in sign-out. The sign-out flow uses the container after awaits rather than accessing a potentially disposed `WidgetRef`.
- Reordered sign-out so the returning-account-choice marker is persisted before Guest activation. No local workspace or cloud backup is deleted.
- Strengthened the existing sign-out widget test to assert no uncaught framework exception occurs.

**Verification:**
- The pre-change full suite passed 804 tests; that result does not verify these new code changes.
- Formatting, analyzer, targeted tests, full suite, debug APK build, and physical-device sign-out/restart checks are **pending**.
- Do not treat the concurrent-modification hypothesis as confirmed until the focused regression test and device reproduction pass. If the error remains, capture its full stack trace and continue diagnosis without suppressing it.

**Safety:** Existing local data, cloud backups, and user stashes must remain untouched. No uninstall, storage clear, data reset, merge, or release action is authorized by this task.

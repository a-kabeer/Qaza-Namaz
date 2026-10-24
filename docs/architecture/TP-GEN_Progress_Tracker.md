# TP-GEN Progress Tracker — Separate Encrypted Local Database per Google Account

**Last updated:** 2026-10-24 (Asia/Karachi) — four targeted test files rerun successfully; Drift warnings still open  
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
| Full test suite | **Rerun pending** | Previous full run failed with `+790 -10`. All four targeted test files for the ten failure categories have now been rerun locally and passed; the complete suite has not yet been rerun. |
| Static analysis | **Needs re-check** | Last previously reported run had no analyzer errors but reported 4 warnings and 26 informational notices. Rerun on the current synchronized checkout before final acceptance. |
| Database/account architecture | **Not yet accepted; Drift warning requires investigation** | Stage 4 adoption/export tests pass, but their output repeatedly warns that multiple `GoogleWorkspaceDatabase`/`AppDatabase` instances may share one `QueryExecutor`, which Drift says can cause race conditions/corruption. The warning is not proof of an actual corruption bug, but it is a concrete connection-ownership risk that must be traced before acceptance. |
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

The user has synced the test-fix commits and confirmed all four targeted test groups pass. **Next run the full suite and static analysis, then record the actual outputs here.** Before accepting Stage 4, investigate the Drift warning in `stage4_adoption_export_test.dart`: trace the injected `GoogleWorkspaceDatabase.forTesting` factory, staging database lifecycle, and manager caches to determine whether the instances use the same executor and whether each instance is intentionally opened/closed. Do not silence `dontWarnAboutMultipleDatabases` or treat a passing test as sufficient evidence.

Run one command at a time from the repository root:

```powershell
flutter test
flutter analyze
```

Keep `pubspec.lock` modified exactly as it is unless its diff is reviewed; do not reset it as part of syncing or test cleanup. If the full suite fails, capture each remaining failure and fix the underlying cause, then rerun the affected tests and full suite. Update this tracker after each meaningful result. Do not build a release APK or declare the branch ready for merge while the full-suite, static-analysis, Drift lifecycle, and architecture gates remain unresolved.

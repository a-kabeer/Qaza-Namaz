# Qaza Namaz — Production Cleanup & Optimization Audit

Date: 2026-09-19

## Scope and evidence

This audit covered the repository tree, production Dart/Flutter code, tests, Android configuration, assets, localization, persistence, sync, dependencies, and project documentation.

Evidence sources used:
- Full recursive Git tree at audit branch HEAD.
- Commit history and file-level diffs to understand legacy migrations and prior cleanup work.
- Current production imports/reference paths and provider wiring.
- Current test references for candidate code.
- Android manifests/Gradle configuration and Flutter CI workflow.
- Canonical architecture/database/offline-first documentation.

The repository contains 263 files at the final audit branch HEAD:
- lib: 102
- test: 83
- android: 22
- assets: 6
- docs: 37
- .github: 1
- root: 12

The full tree was not truncated.

## Cleanup principles

Deletion was limited to items whose current role was disproven across production wiring and test/runtime references. Persisted data, migrations, active plugins, native configuration, and compatibility APIs were retained when their safety could not be established.

## Definitely dead / obsolete — removed

### Production code

- `dummy`
  - Zero-byte file with no runtime/configuration role.

- `lib/features/home/home_state.dart`
  - `HomeStateResolver`, `HomeLedgerState`, and related enums were no longer imported by the current Home implementation.
  - Current Home derives its UI directly from the aggregate progress model.
  - The only remaining reference was an obsolete test group; that test group was removed with the dead implementation.

- `lib/core/widgets/progress_overview_card.dart`
  - No active production consumer.
  - Superseded by the current Home progress presentation.

- `lib/core/widgets/metric_tile.dart`
  - Only consumed by the removed `ProgressOverviewCard`.
  - No active production/test consumer remained.

- `lib/data/repositories/drift_qaza_repository.dart`
  - Not wired into the production dependency graph.
  - Production construction uses `OfflineFirstQazaRepository -> QazaLocalStore -> DriftQazaLocalStore -> Drift/SQLite`.
  - The direct Drift repository represented a duplicate persistence adapter outside the current architecture.

### Redundant tests

Removed tests whose sole purpose was validating the deleted direct-Drift adapter or duplicating current coverage around that adapter:
- `test/drift_qaza_repository_test.dart`
- `test/final_application_regression_test.dart`
- `test/qaza_bounded_read_paths_test.dart`
- `test/qaza_mutation_hardening_test.dart`

The remaining live-path coverage is preserved through:
- DAO/schema tests
- Drift local-store tests
- Offline-first repository tests
- service/business-rule tests
- large-ledger/performance regression tests
- Qaza UI flow and synchronization regression tests

### Localization

Removed two localization keys that had no current production or test consumers after the dead progress card was removed:
- `progressNoRecords`
- `progressPercentCompleted`

Updated both English and Urdu ARB files and the checked-in generated localization sources consistently.

### Documentation cleanup

These obsolete root-level point-in-time task status files were moved under the established historical archive rather than destroyed:
- `CALCULATOR_3_STEP_STATUS.md`
- `CALCULATOR_PART11_STATUS.md`
- `QAZA_CALENDAR_UX_STATUS.md`

Archived copies are now under `docs/archive/`.

## Pages/features removed by this audit

No live user-facing page or feature was removed by this audit. The deleted items were dead internal implementations and their obsolete tests.

Previously retired features such as the old Dashboard, NamazWise/PendingDates flows, and the former History/Logs root experience remain absent and were validated as part of the current navigation architecture rather than reintroduced.

## Plugins / dependencies

No package was removed.

The current dependencies were checked against active Dart/native configuration. The following remain intentionally active:
- Firebase core/auth and Google Sign-In
- Firestore
- Drift / drift_flutter
- SharedPreferences
- connectivity_plus
- Riverpod
- file_picker
- hijri
- intl / flutter_localizations

No dependency was removed based solely on an IDE-style unused warning.

## Assets / localization / content

No image/font/native resource was removed.

The Noto Nastaliq Urdu font remains active.

Knowledge Base JSON/schema/content assets remain active and are consumed by the bundled content repository.

Only the two proven-dead localization keys listed above were removed.

## Database / stored data

No Drift table, column, migration, SharedPreferences key, Firestore structure, or persisted user-data format was removed.

The following were intentionally retained:
- Drift schema and generated code
- SharedPreferences -> Drift one-shot migration
- compatibility full-ledger repository APIs
- sync outbox and sync state
- user-scoped data handling

This preserves backward compatibility for existing installations.

## Platform / Android configuration

No Android plugin, permission, manifest receiver, Gradle configuration, Firebase configuration, or native resource was removed because active runtime usage was confirmed or could not be disproven safely.

The following were explicitly preserved:
- Firebase Google Services integration
- Google Sign-In integration
- Drift/SQLite configuration
- Flutter embedding
- Gradle 9.1.0
- AGP 9.0.1
- Kotlin 2.3.20
- **NDK 28.2.13676358 — unchanged**

## Performance audit outcome

No speculative micro-optimizations were introduced.

The current production paths were reviewed for:
- full-ledger reads
- duplicate provider/repository work
- unbounded list loading
- database-side filtering and paging
- summary aggregation
- completion lookups
- availability reads
- sync/bootstrap behavior

The existing architecture already uses:
- aggregate progress queries
- bounded keyset pagination
- bounded pending-record lookup
- date/prayer-scoped availability queries
- local-first Drift reads
- outbox-based synchronization
- chunked large writes
- bounded large-ledger UI behavior

The cleanup therefore focused on removing dead/duplicate architecture rather than changing working performance-sensitive code.

## Active code intentionally retained

- `lib/core/widgets/section_header.dart` — still imported by settings components.
- `lib/features/sync/sync_status_bar.dart` — compatibility wrapper still consumed by data-management UI.
- `lib/features/knowledge_base/presentation/widgets/knowledge_language_switcher.dart` — active in both Knowledge Base list and article detail.
- `lib/domain/services/qaza_service.dart` — canonical business boundary.
- `QazaRepository.getRecords/history` compatibility APIs — retained because migration/data-transfer compatibility still depends on the repository boundary.
- SharedPreferences settings/migration code — active and not interchangeable with the Qaza database.
- Full test-era task files that still exercise current behavior — retained unless their coverage was proven to be duplicate/dead.

## Verification status

### Performed

- Full repository tree inventory.
- Current architecture/dependency mapping.
- Production provider wiring inspection.
- Candidate definition/import/reference inspection.
- Test-reference inspection for deleted items.
- Android/Gradle/manifest review.
- Dependency/plugin usage review.
- Localization reference sweep for deleted keys.
- Post-cleanup tree check confirming all targeted deleted paths are absent.

### Not executable in this environment

A local Flutter runtime/build could not be executed from the workspace because the container could not clone the GitHub repository due network/DNS restrictions.

Therefore this audit does **not** claim a local manual app run, local `flutter analyze`, local `flutter test`, or local Android release build.

The repository already contains a CI workflow that runs:
- `flutter analyze`
- `flutter test`
- Windows tests
- Android debug APK build
- Android release APK build

The cleanup branch will be validated through that PR CI gate.

Fresh-install/existing-data behavior is additionally covered by the existing migration, bootstrap, persistence, sync, and regression tests, but a physical reinstall/device session was not performed in the restricted workspace.

## Remaining technical debt

- Android release signing still falls back to the debug signing configuration when a release keystore is not provided.
- Some project status documents contain historical/stale statements; the four root task-status documents cleaned in this audit are now archived, but the canonical `PROJECT_STATUS.md` still needs a broader historical wording reconciliation.
- Full device-level manual navigation and release artifact inspection still require CI/device execution.

## Audit branch

`cleanup/production-audit-2026-09-19`

This branch intentionally contains only cleanup/documentation changes; no unrelated UI redesign or feature work was introduced.

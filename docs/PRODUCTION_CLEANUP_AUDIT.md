# Production Cleanup Audit

Date: 2026-09-19
Branch: `chore/production-cleanup-audit`
Baseline: `83a0f33e29e2668d0d9de7d170eec7beeb33f0ef`
Cleanup head: `3e0aa7032031eeda6d47b24c335fdbbe3001ecbd`

## Scope

Audited the repository structure, production Dart layering, navigation composition, state/providers, persistence and migration paths, assets/localization declarations, Android configuration, dependencies, tests, and CI workflow.

Current tree inventory at cleanup head: 263 tracked files, 97 Dart files under `lib/`, and 85 Dart test files.

## Cleanup performed

### Definitely dead production files removed

- `dummy` — empty placeholder file with no content or references.
- `lib/core/widgets/metric_tile.dart` — no production or test references.
- `lib/core/widgets/progress_overview_card.dart` — no production or test references; superseded by the current Home-specific progress overview.
- `lib/core/widgets/section_header.dart` — no production or test references.
- `lib/features/calculator/calculator_persistence.dart` — no production references; the current calculator no longer persists/restores calculator snapshots and the latest calculator flow removed the associated estimate/source state.
- `lib/features/calculator/calculator_tracker.dart` — no production references; current calculator uses the calculation domain object directly.
- `lib/features/home/home_state.dart` — no production references; current Home derives its state from the live progress summary and action conditions.

### Obsolete tests removed or consolidated

- `test/task_calculator_part10_test.dart` — tested the removed calculator snapshot persistence layer.
- `test/task_calculator_part7_test.dart` — tested the removed calculator tracker helper layer.
- `test/calculator_date_boundary_contract_test.dart` — retained all boundary and Witr coverage while removing dependency on the deleted tracker helper.
- `test/task_calculator_part12_test.dart` — removed obsolete persistence/tracker regression sections and retained current calculator domain + three-step UI regression coverage.
- `test/task9_test_reconciliation.dart` — removed obsolete HomeStateResolver tests and kept calendar/completion regression coverage.

## Intentionally retained

### Test-only `DriftQazaRepository`

`lib/data/repositories/drift_qaza_repository.dart` has no production import path because the application composes `OfflineFirstQazaRepository` over `DriftQazaLocalStore` + Firestore. It is still used by multiple database/bounded-read/reset/regression tests.

It was intentionally retained in this cleanup instead of deleting the test seam without replacing its coverage. This is classified as **probably obsolete / test-only infrastructure**, not active production wiring.

### SharedPreferences migration

`SharedPreferences` remains required for the one-time legacy-to-Drift migration and for local theme/language preferences. The legacy Qaza ledger migration path was not removed.

### Knowledge-base assets

Both English and Urdu knowledge-base JSON files remain declared and are loaded by the bundled repository. They are not hardcoded widget content.

### Notification platform integration

Android notification permissions, scheduled/boot receivers, timezone packages, and the notification-settings MethodChannel remain because the notification feature references them.

### Android toolchain

The current AGP/Kotlin/Gradle configuration remains untouched by cleanup. NDK is still exactly:

`28.2.13676358`

## Performance audit findings

The current architecture already contains the major evidence-backed performance safeguards:

- keyset pagination for large ledgers;
- targeted completion updates instead of full-ledger rewrite;
- append-only local inserts for large additions;
- database-backed aggregate counts;
- bounded oldest-pending lookup;
- outbox reads separated from ledger reads;
- remote re-pull limited to startup, explicit sync, and reconnect rather than every mutation.

No speculative micro-optimizations were introduced.

## Dependency/configuration audit

The declared runtime dependencies all have active architectural or feature use in the inspected codebase, including Firebase/Auth, Google Sign-In, Drift/SQLite, connectivity, Riverpod, file picker, notifications, timezone handling, Hijri conversion, and localization.

Android manifest receivers/permissions and the Firebase Google-services plugin were retained because they are tied to active integrations.

## Verification baseline

The latest `main` CI run before cleanup was green:

- Analyze: success
- Linux tests: success
- Windows tests: success
- Android debug APK: success
- Android release APK: success

That run corresponded to the baseline commit listed above.

The cleanup branch has not yet been treated as verified until its own CI run completes. Manual device/emulator navigation could not be performed from the GitHub-only execution environment, so navigation confidence is based on static route/flow tracing plus the existing widget/regression test suite and CI build coverage.

## Remaining technical debt

- `DriftQazaRepository` remains as a test-only repository implementation and could be retired later by migrating its remaining regression tests directly to the production local-store/repository composition.
- Historical root/docs/archive status files remain intentionally because they are documentation/history rather than runtime artifacts.

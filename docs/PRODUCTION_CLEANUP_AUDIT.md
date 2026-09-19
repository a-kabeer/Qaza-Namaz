# Production Cleanup Audit

Date: 2026-09-19
Branch: `chore/production-cleanup-audit`
Base: `main` at `83a0f33e29e2668d0d9de7d170eec7beeb33f0ef`

## Scope

Audited the repository structure, production Dart layering, navigation composition, state/providers, persistence and migration paths, assets/localization declarations, Android configuration, dependencies, tests, and CI workflow.

Final branch diff contains 6 code/artifact deletions plus one focused regression-test cleanup. No runtime feature, UI redesign, database schema, dependency, asset, or platform integration was removed.

## Definitely dead items removed

- `dummy` — empty placeholder file with no content or references.
- `lib/core/widgets/metric_tile.dart` — no production or test references.
- `lib/core/widgets/progress_overview_card.dart` — no production or test references; current Home uses its own canonical progress overview.
- `lib/core/widgets/section_header.dart` — no production or test references.
- `lib/features/home/home_state.dart` — no production references; Home currently derives actions/content directly from the live progress summary and current flow conditions.

These were verified against the production import graph and test references before deletion.

## Regression-test cleanup

- `test/task9_test_reconciliation.dart` no longer imports or tests the deleted HomeStateResolver. Its calendar selection, calendar availability, and bounded Complete Qaza coverage remains intact.

No calculator implementation or calculator regression coverage was removed.

## Explicit false-positive correction

During PR verification, the first deletion pass incorrectly classified:

- `lib/features/calculator/calculator_persistence.dart`
- `lib/features/calculator/calculator_tracker.dart`

as dead because they had no inbound references in the initial limited production scan.

PR CI then proved the missing dependency path: `lib/features/calculator/calculator_controller.dart` imports both files and calls their APIs. Both files and their related tests were restored before the final branch diff was produced.

This was a deliberate evidence-based correction: analyzer/build output was used to strengthen the reference graph rather than weakening the deletion rule.

## Intentionally retained

### Calculator persistence and tracker helpers

Active production controller dependencies. They must remain until the calculator implementation itself is intentionally refactored and its persisted-data compatibility is addressed.

### Test-only `DriftQazaRepository`

`lib/data/repositories/drift_qaza_repository.dart` has no production import path because the application composes `OfflineFirstQazaRepository` over `DriftQazaLocalStore` + Firestore. It remains used by multiple repository/database/bounded-read/reset regression tests, so it is retained as test infrastructure rather than deleted without replacing those guarantees.

### SharedPreferences and migrations

SharedPreferences remains required for local user preferences and the one-time legacy-to-Drift migration. No persisted Qaza records or migration logic was removed.

### Knowledge-base assets/localization

English and Urdu knowledge-base JSON/content, schema, localization files, and the Noto Nastaliq font remain because they are active runtime assets/content.

### Notifications and Android integration

Notification permissions, scheduled/boot receivers, timezone support, and the Android notification-settings MethodChannel remain because the notification feature uses them.

### Android toolchain

No Android build configuration was removed or redesigned. NDK remains exactly:

`28.2.13676358`

## Dependency and plugin audit

No dependency/plugin was removed. The declared packages have active roles across Firebase/Auth, Google Sign-In, Drift/SQLite, connectivity, Riverpod, file import/export, notifications/timezone, Hijri conversion, localization, and application support.

Because the user requested evidence-based deletion, no package was removed solely due to lack of an obvious direct Dart import.

## Performance audit

The existing implementation already contains the major evidence-backed large-ledger safeguards:

- keyset pagination;
- bounded oldest-pending lookup;
- targeted completion updates;
- append-only local inserts for bulk additions;
- database-backed aggregate counts;
- separated outbox reads;
- remote reconciliation only at startup/explicit-sync/reconnect.

No speculative micro-optimizations were added.

## Navigation / flow audit

The startup path and reachable feature composition were traced through `AuthGate`, `WelcomeScreen`, `AuthenticationScreen`, `WorkspaceShell`, and the feature screens/routes. Active flows reviewed include authentication/guest mode, Home, Qaza tracker, Add Qaza, Complete Qaza, calculator, calendar selection, knowledge base, settings/account, notifications, sync, and data management.

The application has no iOS project directory, so Android is the active native platform in this repository.

## Verification

Latest `main` CI before cleanup was green for:

- Analyze
- Linux tests
- Windows tests
- Android debug APK
- Android release APK

The cleanup PR also executed its own CI. One initial run caught the calculator false-positive and stopped at analyzer errors; those files/tests were restored. A subsequent run confirmed the formatting stage succeeds before analyzer completion, and the final branch verification is still dependent on the latest PR run completing after the restored calculator files and final report update.

The GitHub-only execution environment does not expose a physical Android emulator/device, so manual device navigation could not be performed. Static route/flow tracing plus widget/regression coverage and Android CI builds were used instead; this is explicitly not represented as manual device verification.

## Remaining technical debt

- `DriftQazaRepository` is test-only infrastructure that could be retired later if its remaining regression coverage is migrated to a different test seam.
- Historical root/docs/archive status documents remain intentionally; they are documentation/history, not runtime dead code.
- CI still reports numerous pre-existing analyzer *info* lints/deprecations; they were not broadened into this cleanup because they are unrelated to dead-code removal and would create a larger refactor surface.

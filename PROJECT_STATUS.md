# Qaza Namaz App — Project Status

## Current Task
Global reusable UI component layer — implementation complete; CI validation is pending on the current commit.

## Completion Status
- Task 1: COMPLETE & VERIFIED — Qaza ledger business workflow and tests.
- Task 2: COMPLETE & VERIFIED — Firebase Authentication, Google Sign-In, Firestore persistence, user-scoped rules, and Android runtime verification.
- Task 3A–3J: COMPLETE — authentication, Riverpod app shell, Qaza entry/completion, calendar package integration, history/progress, settings/theme, offline-first sync, export/import, and notifications are preserved.
- Architecture: shared Riverpod providers remain the composition point for account, theme, ledger, calendar, notifications, and sync. UI refactors do not change business logic or data boundaries.

## Global Reusable UI — 2026-09-15
- Added focused reusable components under `lib/core/widgets/`: `app_scaffold.dart`, `app_button.dart`, `app_card.dart`, `section_header.dart`, `metric_tile.dart`, `prayer_card.dart`, `date_display.dart`, `state_widgets.dart`, `confirmation_dialog.dart`, and `sync_status.dart`.
- Centralized shared spacing/radius tokens with `AppSpacing` and `AppRadius`, and centralized app date/date-time display helpers in `date_display.dart` on top of the existing `DateFormatters` utility.
- `components.dart` is now a compatibility barrel instead of the primary implementation file. `legacy_components.dart` retains only compatibility wrappers/shared settings/progress pieces that are still used by existing screens/tests.
- Dashboard now directly uses `AppScaffold`, `AppButton`, `AppCard`, `SectionHeader`, `MetricTile`, `PrayerCard`, `SyncStatus`, and shared progress/status widgets.
- Settings and Data & Cloud now directly use `AppScaffold`, `AppCard`, `SyncStatus`, and centralized date formatting.
- Sync status rendering is centralized in `core/widgets/sync_status.dart`; `features/sync/sync_status_bar.dart` remains only as a compatibility wrapper for existing callers/tests.
- Existing loading/error/empty state behavior and confirmation behavior are preserved through reusable shared components.
- No business logic, Riverpod providers, services, repositories, Firestore rules, or data models were changed.
- No one-off feature UI was promoted merely for structural symmetry; focused components were created only where reuse/configurability was meaningful.

## Feature Structure Cleanup — 2026-09-15
- Root application composition is now `lib/app/app.dart`; `lib/main.dart` boots it through `ProviderScope`.
- Onboarding is split into focused screens: `features/onboarding/splash_screen.dart`, `welcome_screen.dart`, and `first_time_setup_screen.dart`.
- Dashboard remains in `features/dashboard/dashboard_screen.dart`.
- Calculator is in `features/calculator/calculator_screen.dart`.
- Qaza entry/completion is split into `features/qaza/add_qaza_screen.dart`, `completion_screen.dart`, `namaz_wise_screen.dart`, and `pending_dates_screen.dart`.
- Settings is split into focused account, notifications, and settings screens. `settings_screens.dart` is only a thin export barrel for existing callers; it contains no duplicate implementation.
- Data management remains isolated in `features/data_management/qaza_data_management_screen.dart` because it has a distinct feature responsibility.
- Workspace remains in `features/shell/workspace_shell.dart`.
- The combined `features/history/history_progress.dart` screen is intentionally retained because the current UX presents logs and progress as one screen rather than two independently navigated responsibilities.
- Removed obsolete temporary production files: root `app.dart`, onboarding monolith, Qaza V2 flow files, and previous `final_ui`/V2 production entry points.

## Riverpod / Data Access Optimization — 2026-09-15
- Qaza add flow awaits the existing `qazaRecordsProvider` for the ledger snapshot instead of issuing a second direct service read for the same data.
- Completion, dashboard, settings, calendar, notifications, and sync screens consume the existing providers/services rather than constructing or threading repositories through widgets.

## Data/Test Doubles
- `InMemoryQazaRepository` and `InMemoryQazaLocalStore` are deterministic test doubles used by the current tests; they are not selected as the production runtime storage path.

## Calendar Boundary
The app uses the maintained `hijri: ^3.0.1` package for Hijri/Umm al-Qura conversion and month data. Calendar UI state is a thin Riverpod adapter in `features/calendar/calendar_controller.dart` and `calendar_picker.dart`; calendar mathematics are delegated to the package. Qaza records remain canonical Gregorian dates. No custom calendar engine remains.

## Test Suite Audit — 2026-09-15
- Existing functional coverage was retained while imports and widget paths were updated for the focused feature structure and shared UI migration.
- Qaza add, completion, calendar, history/progress, settings/account, workspace, repository, data-transfer, sync, and notification coverage remains in the suite.
- Stable keys/finders are retained for refactored UI flows.
- No assertions were weakened, skipped, or suppressed.

## Validation — CURRENT RUN PENDING
- Previous refactor baseline `1e34a8c345071eb88ad9c7fafd164352a93fc57e` passed `flutter pub get`, `flutter analyze`, and `flutter test` on CI run `34987120636`.
- The reusable-component changes are on the current `main` tip and require a fresh CI result before being marked verified.
- No current `flutter analyze` or `flutter test` result is claimed as PASS yet.

## Remaining Issues / Technical Debt
- Final current-commit CI validation must complete before this task can be marked fully verified.
- Physical-device verification of Android notification permission, reboot rescheduling, and export/import picker behavior remains environment-dependent.
- Existing Flutter informational deprecation findings remain outside the functional task scope.
- Google is the connected authentication provider; unsupported email/phone/WhatsApp authentication is not presented as functional.
- Urdu localization and other separately scoped features remain intentionally unimplemented.

## Last Updated
2026-09-15

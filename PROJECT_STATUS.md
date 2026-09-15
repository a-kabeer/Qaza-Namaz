# Qaza Namaz App — Project Status

## Current Task
Global reusable UI component layer — COMPLETE & VERIFIED.

## Completion Status
- Task 1: COMPLETE & VERIFIED — Qaza ledger business workflow and tests.
- Task 2: COMPLETE & VERIFIED — Firebase Authentication, Google Sign-In, Firestore persistence, user-scoped rules, and Android runtime verification.
- Task 3A–3J: COMPLETE — authentication, Riverpod app shell, Qaza entry/completion, calendar package integration, history/progress, settings/theme, offline-first sync, export/import, and notifications are preserved.
- Architecture: shared Riverpod providers remain the composition point for account, theme, ledger, calendar, notifications, and sync. UI refactors do not change business logic or data boundaries.

## Global Reusable UI — 2026-09-15
- Added focused reusable components under `lib/core/widgets/`: `app_scaffold.dart`, `app_button.dart`, `app_card.dart`, `section_header.dart`, `metric_tile.dart`, `prayer_card.dart`, `date_display.dart`, `state_widgets.dart`, `confirmation_dialog.dart`, and `sync_status.dart`.
- Centralized shared spacing/radius tokens with `AppSpacing` and `AppRadius`, and centralized app date/date-time display helpers in `date_display.dart` on top of the existing `DateFormatters` utility. fileciteturn1280file0L2-L5
- `components.dart` is now a compatibility barrel; `legacy_components.dart` contains only compatibility/shared settings/progress wrappers that existing callers/tests still need. The compatibility layer delegates reusable card, scaffold, date, metric, prayer, and confirmation behavior to the new focused components. fileciteturn1281file0L2-L6
- Dashboard directly uses the new scaffold, button, card, section header, metric, prayer, sync, progress, and status components.
- Settings/Data & Cloud directly use the new scaffold, card, sync status, and centralized date display helpers. fileciteturn1293file0L2-L6
- `features/sync/sync_status_bar.dart` is only a compatibility wrapper around the shared `SyncStatus` component.
- `NamazWiseScreen` retains its existing compatibility entry point while its prayer tile delegates to the shared `PrayerCard`.
- No business logic, Riverpod providers, services, repositories, Firestore rules, or data models were changed.
- No one-off feature UI was promoted merely for structural symmetry; focused components were created only where reuse/configurability was meaningful.

## Feature Structure Cleanup — 2026-09-15
- Root application composition is `lib/app/app.dart`; `lib/main.dart` boots it through `ProviderScope`.
- Onboarding is split into focused screens: `features/onboarding/splash_screen.dart`, `welcome_screen.dart`, and `first_time_setup_screen.dart`.
- Dashboard remains in `features/dashboard/dashboard_screen.dart`.
- Calculator is in `features/calculator/calculator_screen.dart`.
- Qaza entry/completion is split into `features/qaza/add_qaza_screen.dart`, `completion_screen.dart`, `namaz_wise_screen.dart`, and `pending_dates_screen.dart`.
- Settings is split into focused account, notifications, and settings screens. `settings_screens.dart` is only a thin export barrel for existing callers.
- Data management remains isolated in `features/data_management/qaza_data_management_screen.dart`.
- Workspace remains in `features/shell/workspace_shell.dart`.
- The combined `features/history/history_progress.dart` screen is intentionally retained because the current UX presents logs and progress as one screen.
- Removed obsolete temporary production files: root `app.dart`, onboarding monolith, Qaza V2 flow files, and previous `final_ui`/V2 production entry points.

## Riverpod / Data Access Optimization — 2026-09-15
- Qaza add flow awaits the existing `qazaRecordsProvider` for the ledger snapshot instead of issuing a second direct service read for the same data.
- Completion, dashboard, settings, calendar, notifications, and sync screens consume the existing providers/services rather than constructing or threading repositories through widgets.

## Data/Test Doubles
- `InMemoryQazaRepository` and `InMemoryQazaLocalStore` are deterministic test doubles used by the current tests; they are not selected as the production runtime storage path.

## Calendar Boundary
The app uses the maintained `hijri: ^3.0.1` package for Hijri/Umm al-Qura conversion and month data. Calendar UI state is a thin Riverpod adapter; calendar mathematics are delegated to the package. Qaza records remain canonical Gregorian dates. No custom calendar engine remains.

## Test Suite Audit — 2026-09-15
- Existing functional coverage was retained while imports and widget paths were updated for the focused feature structure and shared UI migration.
- Qaza add, completion, calendar, history/progress, settings/account, workspace, repository, data-transfer, sync, and notification coverage remains in the suite.
- Stable keys/finders are retained for refactored UI flows.
- No assertions were weakened, skipped, or suppressed.

## Validation — VERIFIED
- CI run `34992021518` on commit `982fd3a09138d9c830958cd36bba902bb5279620` completed `flutter pub get`, `flutter analyze`, and `flutter test` successfully. The full test workflow reported all tests passing.
- CI run `34992021397` on the same commit completed its Linux `Analyze` and `Tests (Linux)` jobs successfully; Windows and Android jobs were still running when the status was last checked.
- A prior test-run regression was identified and fixed before this verified run: the reusable account component now preserves the user's visible email identity as well as the display name and UID, matching the existing account behavior.

## Remaining Issues / Technical Debt
- Physical-device verification of Android notification permission, reboot rescheduling, and export/import picker behavior remains environment-dependent.
- Existing Flutter informational deprecation findings remain outside the functional task scope.
- Google is the connected authentication provider; unsupported email/phone/WhatsApp authentication is not presented as functional.
- Urdu localization and other separately scoped features remain intentionally unimplemented.

## Last Updated
2026-09-15

# Qaza Namaz App — Project Status

## Current Task
Riverpod architecture cleanup and project structure refactor — implementation complete; final CI validation is pending on the latest commit.

## Completion Status
- Task 1: COMPLETE & VERIFIED — Qaza ledger business workflow and tests.
- Task 2: COMPLETE & VERIFIED — Firebase Authentication, Google Sign-In, Firestore persistence, user-scoped rules, and Android runtime verification.
- Task 3A–3J: COMPLETE — authentication, Riverpod app shell, Qaza entry/completion, calendar package integration, history/progress, settings/theme, offline-first sync, export/import, and notifications are preserved.
- Architecture: shared Riverpod providers remain the composition point for account, theme, ledger, calendar, notifications, and sync. Unnecessary screen-level repository/user/theme constructor threading was removed.

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

## Global Reusable UI — 2026-09-15
- Shared UI primitives remain centralized in `lib/core/widgets/components.dart` and are used by dashboard, history/progress, settings, Qaza flows, and supporting screens.
- Reused scaffold, buttons, section headings, status chips, metric/progress widgets, prayer tiles, loading/error/empty states, settings rows/sections, confirmation UI, account UI, date/time wrappers, and sync status components instead of recreating feature-local versions.
- Gregorian formatting is centralized in `lib/core/utils/date_formatters.dart`.
- No duplicate calendar-label helper or second global component layer was introduced.

## Riverpod / Data Access Optimization — 2026-09-15
- Qaza add flow now awaits the existing `qazaRecordsProvider` for the ledger snapshot instead of issuing a second direct service read for the same data.
- Completion, dashboard, settings, calendar, notifications, and sync screens consume the existing providers/services rather than constructing or threading repositories through widgets.

## Data/Test Doubles
- `InMemoryQazaRepository` and `InMemoryQazaLocalStore` were audited. They are deterministic test doubles used by the current tests; they are not selected as the production runtime storage path.
- They remain available because removing them would require replacing existing test infrastructure rather than removing dead production logic.

## Calendar Boundary
The app uses the maintained `hijri: ^3.0.1` package for Hijri/Umm al-Qura conversion and month data. Calendar UI state is a thin Riverpod adapter in `features/calendar/calendar_controller.dart` and `calendar_picker.dart`; calendar mathematics are delegated to the package. Qaza records remain canonical Gregorian dates. No custom calendar engine remains.

## Test Suite Audit — 2026-09-15
- Existing functional coverage was retained while imports and widget paths were updated for the focused feature structure.
- Qaza add, completion, calendar, history/progress, settings/account, workspace, repository, data-transfer, and notification coverage remains in the suite.
- Stable keys/finders are used for refactored UI flows.
- No assertions were weakened, skipped, or suppressed.

## Validation — VERIFIED / CURRENT RUN PENDING
- Previous refactor baseline `1e34a8c345071eb88ad9c7fafd164352a93fc57e` passed `flutter pub get`, `flutter analyze`, and `flutter test` on CI run `34987120636`.
- Current cleanup commit `a31b735591129882b514c0b996144b33a9e16493` contains the latest implementation and the root-cause fix for the prior analyzer error (`NamazWiseScreen` import).
- Current CI run `34989008866` is queued for the latest commit; therefore current `flutter pub get` / `flutter analyze` / `flutter test` results are not yet claimed as PASS.
- An earlier current-commit analyzer attempt failed only because `NamazWiseScreen` was not imported by `completion_screen.dart`; that root cause was corrected before the latest commit.
- A separate runner setup failure occurred on an earlier attempt and was retried; it was infrastructure setup, not a source-code diagnostic.

## Remaining Issues / Technical Debt
- Final current-commit CI validation must complete before the refactor can be marked fully verified.
- Physical-device verification of Android notification permission, reboot rescheduling, and export/import picker behavior remains environment-dependent.
- Existing Flutter informational deprecation findings remain outside the functional task scope.
- Google is the connected authentication provider; unsupported email/phone/WhatsApp authentication is not presented as functional.
- Urdu localization and other separately scoped features remain intentionally unimplemented.

## Last Updated
2026-09-15

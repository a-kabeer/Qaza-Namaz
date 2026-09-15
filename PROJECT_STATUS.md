# Qaza Namaz App — Project Status

## Current Task
Task 3A–3J — COMPLETE TASK 3, RIVERPOD-FIRST.

## Completion Status
- Task 1: COMPLETE & VERIFIED — Qaza ledger business workflow and tests.
- Task 2: COMPLETE & VERIFIED — Firebase Authentication, Google Sign-In, Firestore persistence, user-scoped rules, and Android runtime verification.
- Task 3A: COMPLETE — Google authentication lifecycle, splash/welcome/sign-in flow, Firebase session restoration, persisted first-time setup, sign-out, and active UID session scoping.
- Task 3B: COMPLETE — Riverpod-based app shell, live dashboard totals/progress, Qaza navigation, and loading/error/empty/refresh states.
- Task 3C: COMPLETE — single/range Qaza entry, Gregorian/Hijri calendar integration, review-before-save, future-date protection, duplicate-safe records, and Gregorian original-date preservation.
- Task 3D: COMPLETE — oldest-first completion, prayer-wise views, multi-select/select-all/clear-all, real completion timestamps, double-completion protection, and independent Witr handling.
- Task 3E: COMPLETE — centralized history/progress providers, newest completion ordering, original-vs-completion dates, and shared loading/error/empty/refresh handling.
- Task 3F: COMPLETE — system/light/dark theme provider, shared Stitch design system/components, Firebase account display, and provider-driven sign-out/settings UI.
- Task 3G: COMPLETE — custom calendar engine removed; Gregorian/Hijri switching, conversion, single/range/multiple selection, navigation, future protection, Qaza indicators, and canonical Gregorian storage now use the maintained `hijri: ^3.0.1` package plus a thin Riverpod selection controller. No custom Hijri converter/model/engine remains.
- Task 3H: COMPLETE — offline-first local persistence, UID-isolated cache, durable outbox, connectivity-triggered sync, retry behavior, deterministic merge rules, and sync status reporting.
- Task 3I: COMPLETE — versioned JSON export/import, full pre-import validation, duplicate protection, deterministic conflict handling, current-account ownership remapping, preview/confirmation UI, and Android-compatible file handling.
- Task 3J: COMPLETE — Android local daily reminders, permission handling, persisted reminder settings, single stable schedule, inexact scheduling, reboot/package-replacement rescheduling, and dedicated tests.
- Architecture Refactor: COMPLETE — shared Riverpod providers remain the composition point for account, theme, ledger, calendar, notifications, and sync; unnecessary screen-level repository/user/theme constructor threading was removed.

## Feature Structure Cleanup — 2026-09-15
- Reorganized generic UI into focused feature folders without creating parallel architectures:
  - `features/onboarding/onboarding_screens.dart`
  - `features/dashboard/dashboard_screen.dart`
  - `features/history/history_progress.dart`
  - `features/settings/settings_screens.dart`
  - `features/data_management/qaza_data_management_screen.dart`
  - `features/shell/workspace_shell.dart`
- Removed the obsolete `features/ui/` production files after confirming their active screen references were migrated.
- Removed temporary `_v2` and `final_ui` production entry points from the active feature structure.
- Kept Qaza add/completion, calendar, notifications, and sync under their existing focused feature folders.

## Global Reusable UI — 2026-09-15
- Shared UI primitives are centralized in `lib/core/widgets/components.dart`.
- Reused shared scaffold, buttons, section headings, status chips, metric/progress widgets, prayer tiles, loading/error/empty states, settings rows/sections, confirmation UI, account UI, date/time wrappers, and sync status components across affected screens.
- Gregorian formatting is centralized in `lib/core/utils/date_formatters.dart`.
- No separate duplicate feature-local components or calendar-label helper remain.

## Test Suite Audit — 2026-09-15
- Audited all 11 files under `test/`; retained the existing functional coverage rather than deleting tests to reduce count.
- Updated workspace/history/settings tests for the new feature paths and Riverpod-driven screens.
- No test coverage was intentionally removed or assertions weakened.
- `InMemoryQazaRepository` remains in production data because it is directly useful to the test suite as a repository implementation; it is not used as the application's runtime repository.

## Calendar Boundary
The app uses `hijri: ^3.0.1` for Hijri/Umm al-Qura conversion and month data. Calendar UI state is a thin Riverpod adapter; calendar mathematics are delegated to the package. Qaza records remain canonical Gregorian dates.

## Validation — VERIFIED
- `flutter pub get`: PASS on current commit `1e34a8c345071eb88ad9c7fafd164352a93fc57e` (Flutter CI run `34987120636`).
- `flutter analyze`: PASS on current commit `1e34a8c345071eb88ad9c7fafd164352a93fc57e` (Flutter CI runs `34987120636` and `34987120758`).
- `flutter test`: PASS — all existing tests on current commit `1e34a8c345071eb88ad9c7fafd164352a93fc57e` (Flutter CI run `34987120636`).
- Linux tests: PASS on current commit `1e34a8c345071eb88ad9c7fafd164352a93fc57e` (Flutter CI run `34987120758`).
- Windows test job and Android debug/release APK job were still running at the time of this status update; they are not marked PASS here until completed.

## Remaining Issues / Technical Debt
- Physical-device verification of Android notification permission, reboot rescheduling, and export/import picker behavior remains environment-dependent.
- Existing Flutter informational deprecation findings remain outside the functional task scope.
- Google is the connected authentication provider; unsupported email/phone/WhatsApp authentication is not presented as functional.
- Urdu localization and other separately scoped features remain intentionally unimplemented.

## Last Updated
2026-09-15

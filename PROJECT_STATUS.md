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
- Architecture Refactor: COMPLETE — Riverpod composition root and shared derived ledger state remove repeated dependency threading and duplicate reads.

## Task 3G Package Boundary
The application depends on `hijri: ^3.0.1` for Hijri/Umm al-Qura conversion and month data. Calendar UI state lives in `CalendarController` under Riverpod; it does not implement calendar mathematics. The calendar picker uses Flutter Material localization for Gregorian display formatting and the package directly for Hijri conversion/month lengths. Qaza records remain canonical Gregorian dates.

## Test Suite Audit — 2026-09-15
- Audited all 11 files under `test/`; retained 67 tests protecting current production behavior.
- Updated: `test/qaza_add_flow_test.dart` and `test/task3g_calendar_test.dart` for the current Riverpod active-user dependency, stable widget keys, and viewport-safe action interaction.
- Merged: none; the potentially overlapping Qaza add-flow and calendar tests protect different UI/selection layers.
- Removed: none; no obsolete, debug, temporary, duplicate, or deleted-code tests were found.
- Added: none; the existing suite already covers the important current production behaviors requested by the audit.

## Riverpod / Global UI Cleanup — 2026-09-15
- Finished the active Riverpod migration in the audited application flows: shared account, theme, ledger, calendar-selection, notification and sync state are consumed from providers rather than constructor-threaded dependencies.
- Replaced the V2 production entry points with clean feature names: `QazaAddFlowScreen`, `CompleteQazaScreen`, `NamazWiseScreen`, `PendingDatesScreen`, `HistoryProgressScreen`, and `WorkspaceShell`.
- Moved reusable UI primitives to `lib/core/widgets/components.dart` and common Gregorian formatting to `lib/core/utils/date_formatters.dart`.
- Migrated affected screens and tests to the shared components and clean production names.
- Removed confirmed-unused legacy V2 files, the obsolete feature-local component copy, the old calendar formatting location, and unconnected planned phone verification / forgot-password screens.
- Preserved the existing service/repository boundary, QazaRecord business rules, offline-first repository, Firestore behavior, and maintained Hijri package integration.

## Validation — VERIFIED
- `flutter pub get`: PASS.
- `flutter analyze`: PASS on Flutter CI workflow run `34984847716` / commit `8d94d7f3d10f677a48a934c60e288d8b610b4c66`.
- `flutter test`: PASS — 67 tests on the same verified run.
- Linux tests: PASS on Flutter CI workflow run `34984847782` / cleanup commit.
- Windows tests: PASS on Flutter CI workflow run `34984847782` / cleanup commit.
- Android debug/release build validation was still running when this status file was last verified; no Android failure had been reported at that time.

## Remaining Issues / Technical Debt
- Physical-device verification of Android notification permission, reboot rescheduling, and export/import picker behavior remains environment-dependent.
- Existing Flutter informational deprecation findings remain outside the functional task scope.
- Google is the connected authentication provider; unsupported email/phone/WhatsApp authentication is not presented as functional.
- Urdu localization and other separately scoped features remain intentionally unimplemented.

## Last Updated
2026-09-15

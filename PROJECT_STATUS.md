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
- Task 3G: COMPLETE — custom calendar engine removed; Gregorian/Hijri switching, conversion, single/range/multiple selection, navigation, future protection, Qaza indicators, and canonical Gregorian storage now use the existing maintained `hijri: ^3.0.1` package plus a thin Riverpod selection controller. No custom Hijri converter/model/engine remains.
- Task 3H: COMPLETE — offline-first local persistence, UID-isolated cache, durable outbox, connectivity-triggered sync, retry behavior, deterministic merge rules, and sync status reporting.
- Task 3I: COMPLETE — versioned JSON export/import, full pre-import validation, duplicate protection, deterministic conflict handling, current-account ownership remapping, preview/confirmation UI, and Android-compatible file handling.
- Task 3J: COMPLETE — Android local daily reminders, permission handling, persisted reminder settings, single stable schedule, inexact scheduling, reboot/package-replacement rescheduling, and dedicated tests.
- Architecture Refactor: COMPLETE — Riverpod composition root and shared derived ledger state remove repeated dependency threading and duplicate reads.

## Task 3G Package Boundary
The application depends on `hijri: ^3.0.1` for Hijri/Umm al-Qura conversion and month data. Calendar UI state lives in `CalendarController` under Riverpod; it does not implement calendar mathematics. The calendar picker uses Flutter Material localization for Gregorian display formatting and the package directly for Hijri conversion/month lengths. Qaza records remain canonical Gregorian dates.

## Validation
Dedicated Task 3G tests cover package conversion/round-trip, Gregorian leap day, Riverpod single/range/multiple selection, Gregorian/Hijri views, month navigation, future-date blocking, Qaza indicators, and canonical Gregorian persistence through the existing Qaza flow. The full repository CI additionally runs `flutter pub get`, `flutter analyze`, `flutter test`, and Android debug/release APK builds.

## Test Suite Audit — 2026-09-15
- Audited all 11 files under `test/`; retained 67 tests protecting current production behavior.
- Updated: `test/qaza_add_flow_test.dart` and `test/task3g_calendar_test.dart` for the current Riverpod active-user dependency, stable widget keys, and viewport-safe action interaction.
- Merged: none; the potentially overlapping Qaza add-flow and calendar tests protect different UI/selection layers.
- Removed: none; no obsolete, debug, temporary, duplicate, or deleted-code tests were found.
- Added: none; the existing suite already covers the important current production behaviors requested by the audit.
- Verified: `flutter analyze` passed; `flutter test` passed with 67 tests in CI run `34983281314`.

## Remaining Issues / Technical Debt
- Physical-device verification of Android notification permission, reboot rescheduling, and export/import picker behavior remains environment-dependent.
- Existing Flutter informational deprecation findings remain outside the functional task scope.
- Google is the connected authentication provider; unsupported email/phone/WhatsApp authentication is not presented as functional.
- Urdu localization and other separately scoped features remain intentionally unimplemented.

## Last Updated
2026-09-15

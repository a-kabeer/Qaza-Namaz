# Qaza Namaz App — Project Status

## Current Task
Dead/duplicate code cleanup — COMPLETE & VERIFIED.

## Completion Status
- Task 1: COMPLETE & VERIFIED — Qaza ledger business workflow and tests.
- Task 2: COMPLETE & VERIFIED — Firebase Authentication, Google Sign-In, Firestore persistence, user-scoped rules, and Android runtime verification.
- Task 3A–3J: COMPLETE — authentication, Riverpod app shell, Qaza entry/completion, calendar package integration, history/progress, settings/theme, offline-first sync, export/import, and notifications are preserved.
- Architecture: shared Riverpod providers remain the composition point for account, theme, ledger, calendar, notifications, and sync. Cleanup changes only confirmed-unused/relocated code and test support organization.

## Dead / Duplicate Code Cleanup — 2026-09-15
- Audited `lib/data/local/in_memory_qaza_local_store.dart` and `lib/data/repositories/in_memory_qaza_repository.dart` before removal.
- Both implementations were confirmed test-only deterministic doubles referenced by automated tests, not production runtime code.
- Moved them to `test/support/in_memory_qaza_local_store.dart` and `test/support/in_memory_qaza_repository.dart` and removed only the confirmed production copies.
- Updated all confirmed test references, including Qaza service, Qaza flows, calendar, history/progress, settings/account, data transfer, workspace, onboarding, and widget coverage.
- Removed the obsolete `dart:async` import from `test/task3g_calendar_test.dart` after reference/analyzer validation.
- No business logic, domain models, Riverpod providers, production repositories/services, or Firestore rules were deleted or changed.
- No deletion was made without checking references.

## Validation — VERIFIED
- CI run `34993781411` on commit `9770008567dc29a3c89bddf5e40c1fdd24ace65c` completed the dedicated `Analyze` job successfully and `Tests (Linux)` successfully.
- CI run `34993781401` on the same commit completed `flutter analyze` and `flutter test` successfully.
- The cleanup test run passed the full automated test suite.
- The earlier cleanup CI failures were caused by stale/incorrect test import paths after relocation; those root causes were corrected before this verified result.

## Existing Project Notes
- Global reusable UI components are under `lib/core/widgets/` with compatibility barrels where required by existing callers.
- The app uses the maintained `hijri: ^3.0.1` package for calendar conversion; no custom calendar engine remains.
- `InMemoryQazaRepository` and `InMemoryQazaLocalStore` are explicitly test-support doubles only.

## Remaining Issues / Technical Debt
- Physical-device verification of Android notification permission, reboot rescheduling, and export/import picker behavior remains environment-dependent.
- Existing Flutter informational deprecation findings remain outside the functional cleanup scope.
- Google is the connected authentication provider; unsupported email/phone/WhatsApp authentication is not presented as functional.
- Urdu localization and other separately scoped features remain intentionally unimplemented.

## Last Updated
2026-09-15

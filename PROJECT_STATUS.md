# Qaza Namaz App — Project Status

## Current Task
Dead/duplicate code cleanup — implementation complete; CI validation is pending on the cleanup commit.

## Completion Status
- Task 1: COMPLETE & VERIFIED — Qaza ledger business workflow and tests.
- Task 2: COMPLETE & VERIFIED — Firebase Authentication, Google Sign-In, Firestore persistence, user-scoped rules, and Android runtime verification.
- Task 3A–3J: COMPLETE — authentication, Riverpod app shell, Qaza entry/completion, calendar package integration, history/progress, settings/theme, offline-first sync, export/import, and notifications are preserved.
- Architecture: shared Riverpod providers remain the composition point for account, theme, ledger, calendar, notifications, and sync. Cleanup changes only confirmed-unused/relocated code and test support organization.

## Dead / Duplicate Code Cleanup — 2026-09-15
- Audited `lib/data/local/in_memory_qaza_local_store.dart` and `lib/data/repositories/in_memory_qaza_repository.dart` before removal.
- Both implementations are test-only deterministic doubles: they were referenced by the automated tests and are not part of the production provider/runtime path.
- Moved those implementations to `test/support/in_memory_qaza_local_store.dart` and `test/support/in_memory_qaza_repository.dart`.
- Updated the tests that referenced them and removed the production copies so there is one implementation per responsibility.
- No business logic, domain models, Riverpod providers, production repositories/services, or Firestore rules were deleted or changed.
- No deletion was made without a reference check; the confirmed test-only files were relocated rather than discarded.

## Validation — CURRENT RUN PENDING
- Previous verified UI-component baseline passed `flutter analyze` and `flutter test` before this cleanup.
- The cleanup commit is being validated with the repository CI workflows; no current cleanup `flutter analyze`/`flutter test` result is claimed as PASS until the run completes.

## Existing Project Notes
- Global reusable UI components are under `lib/core/widgets/` with compatibility barrels where required by existing callers.
- The app uses the maintained `hijri: ^3.0.1` package for calendar conversion; no custom calendar engine remains.
- `InMemoryQazaRepository` and `InMemoryQazaLocalStore` are now explicitly test-support doubles only.

## Remaining Issues / Technical Debt
- Physical-device verification of Android notification permission, reboot rescheduling, and export/import picker behavior remains environment-dependent.
- Existing Flutter informational deprecation findings remain outside the functional cleanup scope.
- Google is the connected authentication provider; unsupported email/phone/WhatsApp authentication is not presented as functional.
- Urdu localization and other separately scoped features remain intentionally unimplemented.

## Last Updated
2026-09-15

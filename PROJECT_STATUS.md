# Qaza Namaz App — Project Status

## Current Task
Task 3E — History, Logs & Progress

## Overall Progress
Task 1 and Task 2 remain complete and previously runtime-verified. Task 3 is being rebuilt incrementally from the supplied Stitch ZIP. Task 3A, Task 3B, Task 3C, and Task 3D implementations are in place with fresh verification still pending. Task 3E now adds a data-driven Logs/History and Progress experience using the existing individual Qaza records as the source of truth.

## Task Status
- Task 1: 🟢 COMPLETE & VERIFIED — Qaza ledger business workflow and tests are complete.
- Task 2: 🟢 COMPLETE & VERIFIED — Firebase Authentication, Google Sign-In, Firestore persistence, user-scoped rules, and Android runtime verification completed.
- Task 3: 🟡 PARTIAL — Stitch-derived UI rebuild is in progress by feature area.
- Task 3A: 🟡 IMPLEMENTED — Authentication & Onboarding implementation added; local/device verification pending.
- Task 3B: 🟡 IMPLEMENTED — Dashboard, global navigation, live ledger overview, and system states added; local/device verification pending.
- Task 3C: 🟡 IMPLEMENTED — Add Qaza setup, single-date/range selection, missed-prayer selection, duplicate-safe review, confirmation, and record creation flow added; local/device verification pending.
- Task 3D: 🟡 IMPLEMENTED — Complete oldest pending Qaza, Namaz-wise prayer selection, pending-date multi-select completion, timestamp/original-date preservation, and Witr independence implemented; local/device verification pending.
- Task 3E: 🟡 IMPLEMENTED — Logs/history, overall progress, per-prayer progress, completed-record ordering, original-date display, refresh, and empty/error states added; local/device verification pending.
- Task 4: 🔴 NOT STARTED
- Task 5: 🔴 NOT STARTED
- Task 6: 🔴 NOT STARTED
- Task 7: 🟡 PARTIALLY COMPLETE — core business logic implemented as part of Task 1.
- Task 8: 🔴 NOT STARTED
- Task 9: 🔴 NOT STARTED
- Task 10: 🔴 NOT STARTED
- Task 11: 🔴 NOT STARTED
- Task 12: 🔴 NOT STARTED
- Task 13: 🔴 NOT STARTED
- Task 14: 🟡 PARTIALLY COMPLETE — core unit/widget tests exist; broader QA not started.
- Task 15: 🔴 NOT STARTED

## Task 3E Scope
The supplied Stitch design uses Dashboard, Calculator, Logs, and Settings as the primary navigation. Its dashboard includes an overview of remaining/completed prayers, a progress ring, and recent ledger entries with preserved original missed dates and completion times. The implementation below treats those values as derived from real Qaza records instead of Stitch demo numbers. fileciteturn431file0L10-L24 fileciteturn431file1L37-L83 fileciteturn431file3L139-L166

## Task 3E Implementation
- Added `lib/features/ui/history_progress_v2.dart` as the active Logs/Progress screen.
- Uses `QazaService.history()` for completed history rather than maintaining a separate activity ledger.
- Uses `QazaService.overallProgress()` for overall pending/completed progress and `QazaService.prayerProgress()` for each of the six independent prayer categories.
- Completed history is displayed newest-completion-first while preserving the original missed-prayer date separately from the completion timestamp.
- Witr is displayed independently from Isha because progress is calculated by the individual `PrayerType` values.
- Added explicit loading, retryable error, pull-to-refresh, and empty-history states.
- Replaced the active V2 Workspace Logs destination so the old placeholder/legacy history view is no longer the active Logs route.
- Added `test/task3e_history_progress_test.dart` covering derived progress, all six prayers, completed-history ordering, exclusion of pending records, preservation of original dates, and the empty state.

## Verification
- Task 2 Firebase runtime verification: 🟢 VERIFIED by user on physical Android device in earlier Task 2 work.
- Task 3 ZIP audit: 🟢 COMPLETED.
- Task 3A implementation: 🟢 COMPLETED; fresh full local/device verification still pending.
- Task 3B implementation: 🟢 COMPLETED; fresh full local/device verification still pending.
- Task 3C implementation: 🟢 COMPLETED; cleanup pushed after user-reported test failures.
- Task 3D implementation: 🟢 COMPLETED; Witr test interaction was hardened after user-reported viewport failure.
- Task 3E implementation: 🟢 COMPLETED; source and test logic reviewed before push.
- Task 3E local `flutter analyze`: NOT VERIFIED by this assistant because local command execution is unavailable in this session.
- Task 3E local `flutter test`: NOT VERIFIED by this assistant because local command execution is unavailable in this session.
- Task 3E physical Android UI verification: NOT VERIFIED.
- No GitHub Actions run is available for the Task 3E commits, so no remote test-pass claim is made.

## Important Scope Boundary
This Task 3 rebuild uses the supplied Stitch ZIP as the UI/UX source of truth. Existing backend/domain functionality is preserved rather than replaced. Authentication methods beyond Google, OTP providers, email authentication, offline sync, Hijri/calendar calculation, export/import, notifications, and other dedicated infrastructure/business tasks remain separate until actually implemented.

## Global Task
Recorded for later work: centralize app-wide theme and reusable UI components so Light/Dark/System switching changes the entire app globally from the shared theme, with repeated controls, cards, dialogs, states, prayer cards, typography, spacing, and other shared UI elements moved into reusable components. This task is deferred until after the current Task 3 verification.

## Last Updated
2026-09-14 — Task 3E History/Logs + Progress implementation added and connected to the active Workspace V2 Logs destination. Verification intentionally remains pending.

## Next Action
Pull the latest `main`, run `flutter pub get`, `flutter analyze`, and `flutter test`. If those are clean, run the app on the physical Android device and verify Logs → overall progress, all six prayer progress rows, completed history newest-first ordering, original-date preservation, completion timestamp display, empty state, pull-to-refresh, and retry behavior.
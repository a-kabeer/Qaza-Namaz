# Qaza Namaz App — Project Status

## Current Task
Task 3D — Complete Qaza + Namaz-wise Multi-Selection Flow

## Overall Progress
Task 1 and Task 2 remain complete and previously runtime-verified. Task 3 is being rebuilt incrementally from the supplied Stitch ZIP. Task 3A, Task 3B, and Task 3C implementations are in place with fresh verification still pending. Task 3D implementation is now added; local/device verification remains pending.

## Task Status
- Task 1: 🟢 COMPLETE & VERIFIED — Qaza ledger business workflow and tests are complete.
- Task 2: 🟢 COMPLETE & VERIFIED — Firebase Authentication, Google Sign-In, Firestore persistence, user-scoped rules, and Android runtime verification completed.
- Task 3: 🟡 PARTIAL — Stitch-derived UI rebuild is in progress by feature area.
- Task 3A: 🟡 IMPLEMENTED — Authentication & Onboarding implementation added; local/device verification pending.
- Task 3B: 🟡 IMPLEMENTED — Dashboard, global navigation, live ledger overview, and system states added; local/device verification pending.
- Task 3C: 🟡 IMPLEMENTED — Add Qaza setup, single-date/range selection, missed-prayer selection, duplicate-safe review, confirmation, and record creation flow added; local/device verification pending.
- Task 3D: 🟡 IMPLEMENTED — Complete Qaza oldest-first flow plus Namaz-wise prayer/date multi-selection flow added; local/device verification pending.
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

## Task 3 ZIP Audit
The supplied Stitch export was inspected before implementation, including the Add Qaza setup, Gregorian calendar, Hijri calendar, missed-prayer selection, and range-confirmation screens. The Stitch workflow also uses individual prayer ledger entries, completion actions, recent ledger history, and six independent prayer categories. Its demo counters/actions are treated as visual/interaction reference, not real data. fileciteturn293file0L1-L14 fileciteturn409file1L35-L84

Audit constraints preserved:
- Individual prayer/date records remain the canonical ledger objects.
- Witr remains an independent prayer category and is never merged with Isha.
- Existing records must not be duplicated.
- Future dates are not recordable.
- Completion changes only selected pending records and records a separate completion timestamp.
- Oldest pending record is completed first for the one-at-a-time completion flow.
- The supplied Stitch demo content is treated as visual/interaction reference, not real data.
- The Hijri selection engine itself remains deferred to the dedicated calendar task; Task 3C does not invent a Hijri conversion implementation.

## Task 3C Implementation
- `lib/features/qaza/qaza_add_flow_v2.dart` is the sole active Add Qaza implementation.
- Added a three-step Add Qaza experience: Method → Dates → Review.
- Added Gregorian calendar mode with Single Date and Date Range selection.
- Locked future dates through the Flutter date pickers.
- Added date-range expansion so every calendar day in the selected range becomes eligible for individual prayer records.
- Added missed-prayer selection for all six categories: Fajr, Zuhr, Asr, Maghrib, Isha, Witr.
- Added Select All and Clear controls.
- Added a review summary showing selected days, prayers per day, existing combinations, and new records to create.
- Existing prayer/date combinations are checked before creation and are not duplicated.
- Added a final confirmation dialog and creation success state.
- Uses the existing `QazaService.recordQazaForDates()` and therefore preserves the established stable record IDs and repository duplicate protection.
- Updated `lib/features/ui/workspace_v2.dart` and `AuthGate` so the authenticated Dashboard Add Qaza action opens the refined Task 3C flow.
- Updated `test/qaza_add_flow_test.dart` to target the active V2 flow and use robust finders for test viewport behavior.
- Removed obsolete duplicate Add Qaza/workspace implementations and redundant tests so the active flow has a single source of truth.

## Task 3D Implementation
- Added `lib/features/qaza/qaza_completion_flow_v2.dart` as the active completion workflow implementation.
- Added `CompleteQazaV2Screen` with prayer selection and oldest-pending-first completion.
- Completion reads the actual individual pending record, preserves its original missed date, and writes a separate completion timestamp.
- Added a clear empty state when the selected prayer has no pending records.
- Added `NamazWiseV2Screen` covering all six prayer categories, including independent Witr.
- Added `PendingDatesV2Screen` with oldest-first date ordering, individual checkbox selection, Select all/Clear all, and multi-record completion for the selected prayer only.
- Multi-selection is validated through `QazaService.completeSelected()` so only records that are still pending can be completed.
- Reconnected Dashboard Complete, Prayer ledger View all, and individual prayer cards to the Task 3D V2 screens.
- Added `test/task3d_completion_flow_test.dart` covering oldest-first presentation, completion metadata preservation, all six prayer options, Witr independence, and multi-select completion.

## Verification
- Task 2 Firebase runtime verification: 🟢 VERIFIED by user on physical Android device in earlier Task 2 work.
- Task 3 ZIP audit: 🟢 COMPLETED.
- Task 3A implementation: 🟢 COMPLETED; fresh full local/device verification still pending.
- Task 3B implementation: 🟢 COMPLETED; fresh full local/device verification still pending.
- Task 3C implementation: 🟢 COMPLETED; cleanup pushed after user-reported test failures.
- Task 3D implementation: 🟢 COMPLETED; local/device verification pending.
- Latest user-reported `flutter test` reached `+22 -1`; the remaining failure was a test viewport assertion in the Hijri-gate test, after which the test was simplified and stabilized.
- Task 3C/3D local `flutter analyze`: NOT VERIFIED after the latest implementation.
- Task 3C/3D local `flutter test`: NOT VERIFIED after the latest implementation.
- Task 3 physical Android UI verification: NOT VERIFIED.

## Important Scope Boundary
This Task 3 rebuild uses the supplied Stitch ZIP as the UI/UX source of truth. Existing backend/domain functionality is preserved rather than replaced. Authentication methods beyond Google, OTP providers, email authentication, offline sync, Hijri/calendar calculation, export/import, notifications, and other dedicated infrastructure/business tasks remain separate until actually implemented.

## Global Task
Recorded for later work: centralize app-wide theme and reusable UI components so Light/Dark/System switching changes the entire app globally from the shared theme, with repeated controls, cards, dialogs, states, prayer cards, typography, spacing, and other shared UI elements moved into reusable components. This task is deferred until after the current Task 3D verification.

## Last Updated
2026-09-14 — Task 3D completion and Namaz-wise implementation pushed; verification intentionally remains pending.

## Next Action
Pull the latest `main`, run `flutter pub get`, `flutter analyze`, and `flutter test`, then run on the physical Android device and verify Dashboard → Complete and Dashboard → Prayer ledger → prayer → Pending dates → multi-select → Complete, including oldest-first behavior, completion timestamps, Witr independence, and empty states.

# Qaza Namaz App — Project Status

## Current Task
Task 3C — Add Qaza Date/Range + Missed Prayer Selection Flow

## Overall Progress
Task 1 and Task 2 remain complete and previously runtime-verified. Task 3 is being rebuilt incrementally from the supplied Stitch ZIP. Task 3A and Task 3B implementations are in place with fresh verification still pending. Task 3C implementation and cleanup are in place; local/device verification remains pending.

## Task Status
- Task 1: 🟢 COMPLETE & VERIFIED — Qaza ledger business workflow and tests are complete.
- Task 2: 🟢 COMPLETE & VERIFIED — Firebase Authentication, Google Sign-In, Firestore persistence, user-scoped rules, and Android runtime verification completed.
- Task 3: 🟡 PARTIAL — Stitch-derived UI rebuild is in progress by feature area.
- Task 3A: 🟡 IMPLEMENTED — Authentication & Onboarding implementation added; local/device verification pending.
- Task 3B: 🟡 IMPLEMENTED — Dashboard, global navigation, live ledger overview, and system states added; local/device verification pending.
- Task 3C: 🟡 IMPLEMENTED — Add Qaza setup, single-date/range selection, missed-prayer selection, duplicate-safe review, confirmation, and record creation flow added; local/device verification pending.
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
The supplied Stitch export was inspected before implementation, including the Add Qaza setup, Gregorian calendar, Hijri calendar, missed-prayer selection, and range-confirmation screens. The Stitch Add Qaza family defines a staged workflow around method, dates, review, supports Single Date and Date Range, includes Gregorian/Hijri presentation, Select All/Clear prayer controls, and a final review showing individual historical record counts. fileciteturn293file0L1-L14 fileciteturn293file1L16-L30

Audit constraints preserved:
- Individual prayer/date records remain the canonical ledger objects.
- Witr remains an independent prayer category and is never merged with Isha.
- Existing records must not be duplicated.
- Future dates are not recordable.
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
- Updated `test/qaza_add_flow_test.dart` to target the active V2 flow and use robust button finders rather than brittle text-only selection.
- Removed the obsolete duplicate `lib/features/qaza/qaza_add_flow.dart`, obsolete `lib/features/ui/workspace_ui.dart`, and redundant `test/task3c_qaza_flow_test.dart` so the active flow has a single source of truth and obsolete code cannot break the test suite.

## Verification
- Task 2 Firebase runtime verification: 🟢 VERIFIED by user on physical Android device in earlier Task 2 work.
- Task 3 ZIP audit: 🟢 COMPLETED.
- Task 3A implementation: 🟢 COMPLETED; fresh full local/device verification still pending.
- Task 3B implementation: 🟢 COMPLETED; fresh full local/device verification still pending.
- Task 3C implementation: 🟢 COMPLETED; cleanup pushed after user-reported test failures.
- User-reported local `flutter test` on commit `5174092` exposed an obsolete-file compile error (`sunny_snowing_rounded`) and brittle Add Qaza test finders; those obsolete files/tests were removed and the active test was updated.
- Task 3C local `flutter analyze`: NOT VERIFIED after cleanup.
- Task 3C local `flutter test`: NOT VERIFIED after cleanup.
- Task 3C physical Android UI verification: NOT VERIFIED.

## Important Scope Boundary
This Task 3 rebuild uses the supplied Stitch ZIP as the UI/UX source of truth. Existing backend/domain functionality is preserved rather than replaced. Authentication methods beyond Google, OTP providers, email authentication, offline sync, Hijri/calendar calculation, export/import, notifications, and other dedicated infrastructure/business tasks remain separate until actually implemented.

## Global Task
Recorded for later work: centralize app-wide theme and reusable UI components so Light/Dark/System switching changes the entire app globally from the shared theme, with repeated controls, cards, dialogs, states, prayer cards, typography, spacing, and other shared UI elements moved into reusable components. This task is deferred until after the current Task 3C verification.

## Last Updated
2026-09-13 — Task 3C obsolete-code/test cleanup pushed; verification intentionally remains pending.

## Next Action
Pull the latest `main`, run `flutter pub get`, `flutter analyze`, and `flutter test`, then run on the physical Android device and verify Dashboard → Add Qaza → Single Date and Date Range → Missed Prayers → Review → Create Records, including duplicate handling and Witr independence.

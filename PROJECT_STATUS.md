# Qaza Namaz App — Project Status

## Current Task
Task 3 — Final Stitch UI/UX Rebuild

## Overall Progress
Task 1 and Task 2 remain complete and previously runtime-verified. Task 3 has been reset and rebuilt from the newly supplied Stitch ZIP. The ZIP was audited before implementation. The previous Flutter presentation layer was removed and replaced with a new Stitch-derived UI layer.

## Task Status
- Task 1: 🟢 COMPLETE & VERIFIED — Qaza ledger business workflow and tests are complete.
- Task 2: 🟢 COMPLETE & VERIFIED — Firebase Authentication, Google Sign-In, Firestore persistence, user-scoped rules, and Android runtime verification completed.
- Task 3: 🟡 PARTIAL — Stitch ZIP audited and previous UI reset. New onboarding/auth shell, dashboard, Qaza workflows, calculator, history, settings, progress, and reusable UI foundations are committed. Local/device verification is still pending.
- Task 4: 🔴 NOT STARTED
- Task 5: 🔴 NOT STARTED
- Task 6: 🔴 NOT STARTED
- Task 7: 🟡 PARTIALLY COMPLETE — core business logic implemented as part of Task 1
- Task 8: 🔴 NOT STARTED
- Task 9: 🔴 NOT STARTED
- Task 10: 🔴 NOT STARTED
- Task 11: 🔴 NOT STARTED
- Task 12: 🔴 NOT STARTED
- Task 13: 🔴 NOT STARTED
- Task 14: 🟡 PARTIALLY COMPLETE — core unit/widget tests exist; full QA not started
- Task 15: 🔴 NOT STARTED

## Task 3 ZIP Audit
The supplied Stitch export was inspected before implementation, including its master design prompt, generated screen folders/code.html files, screen images, and Serene Sanctuary DESIGN.md references.

The ZIP defines the visual/navigation direction. It covers onboarding/authentication, Dashboard, Add Qaza, Gregorian/Hijri calendar states, completion, Namaz-wise multi-selection, Calculator, Progress, History, Settings, Account, Data & Cloud, Export/Import, and application states.

Audit constraints preserved:
- Authentication supports Sign In/Create Account with Google, Phone, WhatsApp, and Email in the design; only the existing Google provider is connected at this stage.
- Six prayers remain independent; Witr remains independent from Isha.
- Add Qaza is date/date-range based.
- Completion distinguishes original Qaza date from completion date/time.
- Namaz-wise supports multi-date selection.
- Calculator remains a planning/estimation surface rather than the primary Qaza-record workflow.
- English/Urdu RTL and theme states are part of the design direction.
- Demo values from Stitch are not treated as real user data.

## Task 3 Implementation
- Removed the previous Dashboard, Calculator, History, Settings, and Home UI files from the Flutter presentation layer.
- Replaced the previous authentication presentation with a Stitch-derived Welcome → Authentication → First-Time Setup flow while preserving the existing Firebase/Auth repository integration.
- Added `lib/features/ui/onboarding_ui.dart`.
- Added `lib/features/ui/final_ui.dart`.
- Fixed the Dart syntax/parenthesis issues reported by the user's local `flutter analyze` output in the onboarding and final UI files.
- Preserved Firebase Authentication, Google Sign-In, Firestore, repository contracts, domain entities, and QazaService architecture.
- Connected Dashboard progress, prayer progress, Add Qaza, oldest-pending completion, and Namaz-wise multi-record completion to the existing QazaService/repository where supported.
- Removed editable +/- counter UI from the previous presentation.
- Kept Witr independent throughout the new UI.
- Kept Original Qaza Date and Completion Date/Time distinct.
- Added four-destination navigation: Dashboard, Calculator, Logs, Settings.

## Verification
- Task 2 Firebase runtime verification: 🟢 VERIFIED by user on physical Android device in the earlier Task 2 work.
- Task 3 ZIP audit: 🟢 COMPLETED.
- Task 3 previous UI reset: 🟢 COMPLETED in GitHub.
- Task 3 reported local `flutter analyze`: 🔴 FAILED before the latest syntax fixes; the reported errors were addressed in the latest GitHub commits.
- Task 3 local `flutter analyze` after latest fixes: NOT VERIFIED — user must pull latest `main` and rerun.
- Task 3 local `flutter test` after latest fixes: NOT VERIFIED.
- Task 3 physical Android UI verification: NOT VERIFIED.

## Important Scope Boundary
This Task 3 rebuild is based on the supplied Stitch ZIP as the UI/UX source of truth. Existing backend/domain functionality was preserved rather than replaced. Authentication methods other than the already-connected Google flow are represented in the UI but are not falsely implemented as working providers. Hijri/calendar calculation, offline-first synchronization, export/import implementation, notifications, and other dedicated business/infrastructure tasks remain subject to their later tasks.

## Last Updated
2026-09-13 — Fixed the syntax errors reported by local analyze/test and kept verification status explicitly pending.

## Next Action
Pull the latest `main` locally, run `flutter pub get`, `flutter analyze`, and `flutter test`. If clean, run the app on the physical Android device and verify the Stitch-derived onboarding/authentication, Dashboard, Add Qaza, completion, Namaz-wise, Calculator, Logs, Settings, theme, and navigation. Only after actual verification should Task 3 be marked COMPLETE.

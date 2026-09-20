# Firebase App Check

**Priority:** P0  
**Status:** **Merged — Firebase Console / Device QA Pending**

## Task checklist

- [x] Add Firebase App Check
- [x] Configure Play Integrity for Android
- [x] Configure debug provider for development
- [x] Initialize App Check
- [ ] Monitor verification results
- [ ] Enable enforcement after validation

## Current evidence

Implemented in PR #45 and merged to `main`. The app activates the debug provider in development and Play Integrity in production. The remaining release prerequisite is outside the repository: register/verify the Android app in Firebase App Check, monitor verification results, enable enforcement after validation, and complete physical-device verification.

## Definition of Done

- [x] Implementation
- [x] Unit/widget tests — repository test suite passed; App Check startup wiring is part of the merged implementation
- [x] Regression tests
- [x] Analyze
- [x] CI
- [ ] Device QA where required — pending physical-device validation
- [x] UX review — N/A for the Firebase enforcement configuration
- [x] Documentation
- [x] Merge
- [ ] Production Firebase Console configuration and enforcement — pending

## Evidence log

| Date | Status | Evidence |
|---|---|---|
| 2026-09-20 | Implemented | Firebase App Check startup activation added in PR #45. |
| 2026-09-20 | Merged — verification pending | PR #45 merged to `main`; Firebase Console Play Integrity registration/enforcement and physical-device validation remain. |

**Rule:** update this tracking file, not the master plan, when status changes.

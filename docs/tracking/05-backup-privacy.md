# Android backup/privacy hardening

**Priority:** P0  
**Status:** **Merged — Device QA Pending**

_Reconciled 2026-09-22 against `main` @ 505a828. `AndroidManifest.xml` declares `fullBackupContent` and `dataExtractionRules`. Backup/restore behaviour has not been exercised on a device._

## Task checklist

- [x] Review Auto Backup
- [x] Add dataExtractionRules.xml
- [x] Decide local Qaza backup behavior
- [x] Protect sensitive application data
- [x] Document restore behavior
- [ ] Test fresh install + restore

## Current evidence

Implemented in PR #45 and merged to `main`. Android backup/data-extraction policy is wired so the local Qaza database is restricted to encrypted cloud-backup conditions and excluded from device-transfer; SharedPreferences backup is excluded. Physical fresh-install, restore, and device-transfer validation remains pending.

## Definition of Done

- [x] Implementation
- [x] Unit/widget tests — repository regression suite passed
- [x] Regression tests
- [x] Analyze
- [x] CI
- [ ] Device QA where required — pending backup/restore device validation
- [x] UX review — N/A for Android backup configuration
- [x] Documentation
- [x] Merge

## Evidence log

| Date | Status | Evidence |
|---|---|---|
| 2026-09-20 | Implemented | Android backup/privacy rules added in PR #45. |
| 2026-09-20 | Merged — device QA pending | PR #45 merged to `main`; physical restore/transfer validation remains. |

**Rule:** update this tracking file, not the master plan, when status changes.

# App Lock

**Priority:** P0/P1  
**Status:** **Merged — Device QA Pending**

_Reconciled 2026-09-22 against `main` @ 505a828. `lib/features/settings/app_lock_controller.dart` and `app_lock_gate.dart` are wired into `QazaNamazApp` lifecycle handling. Biometric prompt is untested on hardware._

## Task checklist

- [x] Detect biometric/device authentication
- [x] Add lock controller
- [x] Support immediate/1 minute/5 minutes/Never
- [x] Lock on background threshold and resume
- [x] Prevent data visibility while locked
- [x] Accessibility support
- [x] Tests

## Current evidence

Target path: Settings → Privacy & Security → App Lock. Device authentication behavior requires physical-device validation.

## Definition of Done

- [x] Implementation
- [x] Unit tests added
- [ ] Regression tests
- [ ] Analyze
- [ ] CI
- [ ] Device QA where required
- [x] UX/security review
- [ ] Documentation
- [x] Merge

## Evidence log

| Date | Status | Evidence |
|---|---|---|
| 2026-09-20 | Not started | Fresh tracking document created from the shared master plan. |

| 2026-09-20 | Merged | PR #47 merged to `main` with merge commit `9a4301154340838bdd82e59e6046e9442ba4c59f`; CI run #1468 passed all five jobs. Physical-device QA remains pending. |

**Rule:** update this tracking file, not the master plan, when status changes.


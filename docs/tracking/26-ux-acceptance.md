# UX acceptance journeys

**Priority:** P1  
**Status:** **Merged — Device QA Pending**

_Reconciled 2026-09-22 against `main` @ 505a828. All eight journeys are now driven end to end through the real widget tree in `test/ux_acceptance_journeys_test.dart`. These are automated acceptance runs, not a substitute for a human pass on hardware, which is why device QA stays pending._

## Task checklist

- [x] First-time user — welcome surface to a usable workspace as a guest
- [x] Manual Qaza — date, prayer, review, add, and the record exists afterwards
- [x] Calculator — a ten-day expansion reaches the tracker, and re-running it
      adds nothing
- [x] Daily completion — the oldest debt is the one settled, and it is stamped
- [x] Tracker — sort both ways and filter, without disturbing the order
- [x] Guest conversion — signing in never silently discards the guest ledger
- [x] Offline — the ledger reads and writes with no remote behind it
- [x] Notification — a reminder is owed only while something is pending

## Current evidence

Each journey must be tested end-to-end rather than inferred from unit tests.

## Definition of Done

- [ ] Implementation
- [ ] Unit/widget tests
- [ ] Regression tests
- [ ] Analyze
- [ ] CI
- [ ] Device QA where required
- [ ] UX review
- [ ] Documentation
- [ ] Merge

## Evidence log

| Date | Status | Evidence |
|---|---|---|
| 2026-09-20 | Not started | Fresh tracking document created from the shared master plan. |

**Rule:** update this tracking file, not the master plan, when status changes.

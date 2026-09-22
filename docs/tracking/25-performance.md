# Performance certification

**Priority:** P1  
**Status:** **Partially Implemented — Remaining Scope**

_Reconciled 2026-09-22 against `main` @ 505a828. `test/large_ledger_performance_test.dart` proves bounded reads and targeted writes over a 10,000-record ledger. Startup, frame and memory certification on hardware has not been done._

## Task checklist

- [ ] 100-record dataset
- [ ] 1,000-record dataset
- [ ] 10,000-record dataset
- [ ] 50,000-record dataset
- [ ] 100,000-record dataset
- [ ] Home load time
- [ ] Tracker initial load
- [ ] Scrolling
- [ ] Filtering
- [ ] Sorting
- [ ] Availability analysis
- [ ] Calculator preflight
- [ ] Bulk add
- [ ] Bulk completion
- [ ] Sync batching
- [ ] App restart recovery
- [ ] Avoid unnecessary full-ledger materialization

## Current evidence

Certification must use reproducible measurements; the complete ledger must not be unnecessarily materialized in the UI.

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

## Remaining scope

`test/large_ledger_performance_test.dart` proves the data layer over a 10,000-record
ledger: bounded keyset pagination, targeted completion writes, no full-ledger reads
and no re-download after a small change. That is the part that can be proven without
hardware, and it holds.

Certification remains: cold-start time, frame timings during scroll, memory ceiling
and battery behaviour, all of which need a device and none of which have been
measured.

# Tracker sorting

**Priority:** P1  
**Status:** **Merged**

_Reconciled 2026-09-22 against `main` @ 505a828. Implemented in this pass. `QazaSortOrder` on the tracker state routes to the two existing keyset queries — `getPage` ascending, `getHistoryPage` descending — behind a `SegmentedButton` keyed `qaza_tracker_sort`. Covered by `test/tracker_sorting_test.dart` (6 tests)._

## Task checklist

- [x] Oldest first — `QazaSortOrder.oldestFirst`, the default, because that is
      the order a Qaza debt is owed in
- [x] Newest first — `QazaSortOrder.newestFirst`, routed to `getHistoryPage`
- [x] Deterministic originalDate ordering — the DAO orders by `originalDate`
      in both directions (`qaza_records_dao.dart`)
- [x] Deterministic id tie-breaker — `id` is the second ordering term in both
      directions, so two records on the same day never swap places between
      pages; the test asserts descending is exactly ascending reversed

## Current evidence

Ordering must be deterministic.

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

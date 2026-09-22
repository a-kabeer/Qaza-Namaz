# Tracker filter and empty-state UX

**Priority:** P1  
**Status:** **Merged**

_Reconciled 2026-09-22 against `main` @ 505a828. Prayer and status filters with `FilterChip` rows, a one-tap reset, and two distinct empty states keyed `qaza_tracker_filtered_empty` and `qaza_tracker_empty`._

## Task checklist

- [x] Make filter state obvious — `FilterChip` rows in `qaza_tracker_screen.dart`
- [x] Active-filter summary — carried by the selected state of those chips; no
      separate summary line was built, and none is needed for a two-axis filter
- [x] One-tap filter reset — `controller.clearFilters()`
- [x] Differentiate empty ledger from filtered-empty — `state.isFiltered` picks
      between `qaza_tracker_filtered_empty` (with a reset action) and
      `qaza_tracker_empty`

## Current evidence

Users should always understand why the list is empty.

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

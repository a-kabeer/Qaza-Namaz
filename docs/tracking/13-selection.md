# Tracker selection improvements

**Priority:** P1  
**Status:** **Merged**

_Reconciled 2026-09-22 against `main` @ 505a828. The two outstanding items were implemented in this pass. `selectAllMatching()` walks the same bounded keyset query the list uses, a page at a time, capped at 2000; the bulk-completion action confirms first once a selection reaches 25 records. Covered by `test/tracker_sorting_test.dart`._

## Task checklist

- [x] Select all visible — `selectAllLoaded()`
- [x] Clear selection — `clearSelection()`
- [x] Complete selected — `completeSelectedWithUndo()`, with an undo banner
- [x] Select all matching — `selectAllMatching()` pages the whole filtered
      ledger rather than the loaded window, honours the active filter, and
      stops at `selectAllMatchingCap` (2000) so it can never walk an unbounded
      ledger into memory. Reaching the cap is reported to the user.
- [x] Explicit confirmation for very large operations —
      `selectionNeedsConfirmation` at 25 records gates the bulk completion
      behind a confirmation naming the count. Undo remains, but it is no
      longer the only protection.

## Current evidence

Selection must stay bounded for large ledgers.

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

# Import/export & backup UX

**Priority:** P1  
**Status:** **Partially Implemented — Remaining Scope**

_Reconciled 2026-09-22 against `main` @ 505a828. Two further items landed in this pass: a bad file is now explained rather than dumped as a raw exception (`QazaDataTransferException` implements `ClassifiedError`, so it classifies as `malformedData` and correctly offers no Retry), and the UTF-8/Urdu round trip is covered by `test/import_export_regression_test.dart` (7 tests). Three items remain._

## Task checklist

- [x] Export backup summary — `exportJson` with app version and record counts
- [x] Import Select → Analyze → Preview → Confirm → Import → Result —
      `analyzeImport` feeds a confirmation dialog before `applyImport`
- [ ] Large-file progress — **remaining.** Import shows a busy flag, not
      progress. The service would need to report through the analysis the way
      `recordQazaForDates` reports its batches.
- [x] Duplicate handling — the analysis separates new, to-be-completed and
      unchanged, and a re-import of the same backup adds nothing
- [x] Invalid-file explanation — classified as `malformedData` through
      `ClassifiedError`, so the user gets "that file is not a Qaza backup, or
      it is damaged" and no misleading Retry
- [x] UTF-8/Urdu regression — export → bytes → decode → import, including an
      Urdu free-text field, is covered
- [x] Import cancellation — cancelling the picker or the confirmation aborts
      cleanly
- [ ] Partial-failure recovery — **remaining.** `applyImport` writes new
      records and then completions; a failure between the two leaves the
      import half-applied with no resume.
- [ ] Encrypted backup design — **remaining.** Not designed.

## Current evidence

Large data operations must remain explainable and recoverable.

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

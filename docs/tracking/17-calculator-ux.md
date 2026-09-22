# Calculator UX & trust

**Priority:** P1  
**Status:** **Partially Implemented — Remaining Scope**

_Reconciled 2026-09-22 against `main` @ 505a828. The calculator flow, its centralised bounds (`calculator_validation.dart`) and its add/preflight behaviour are merged with seven test files. The "trust" half of this task — explaining the calculation to the user — is largely absent, and some step chrome is still hardcoded English._

## Task checklist

- [ ] Full user-facing localization — **remaining.** `_StepActions` still hardcodes
      "Back", "Continue" and "Calculate", and the Step 2 intro and Witr subtitle are
      hardcoded English in `calculator_screen.dart`.
- [ ] How was this calculated? — **remaining.** No such affordance exists.
- [x] Calculation inputs/outputs — the result card shows period, elapsed days and
      estimated prayers, with a per-prayer breakdown
- [ ] Methodology page — **remaining.** Not built.
- [ ] Boundaries and assumptions — **remaining.** The bounds are enforced and
      explained in error text, but there is no page stating the assumptions.
- [x] Prayer count/Witr/duplicate explanation — `calcWitrNotIncluded`, and the
      preflight names already-recorded and already-completed combinations
- [x] Readable result card
- [x] Preflight explanation — `_PreflightDialog` breaks out calculated, already
      recorded, already completed and new
- [x] Empty/zero-result state — `calcNoResultPrompt`, and `calcAddedResult` has a
      zero case
- [x] Cancel-safe behavior — the preflight is confirmed before anything is written
- [x] Retry behavior — `calc_add_retry`
- [x] Progress persistence/state — determinate add progress, and a snapshot that
      never restores a completed Step 3

## Current evidence

Calculator must be transparent and trustworthy.

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

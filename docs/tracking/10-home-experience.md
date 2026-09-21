# Home experience

**Priority:** P1  
**Status:** **In Progress — PR #61 pending CI**

## Task scope

Complete the Home experience gaps from Phase 4 of the master plan without rebuilding the existing Home architecture.

### Implemented in Task 10

- [x] Daily progress model
- [x] Next Qaza provider
- [x] Completion action
- [x] Qaza plan state
- [x] Completion estimate
- [x] Progress persistence
- [x] Empty/loading/error states
- [x] Tests

### UX acceptance requirements

- [x] Next Qaza uses the oldest pending record across all prayers.
- [x] Deterministic ordering remains `originalDate ASC, id ASC`.
- [x] The primary Complete Next Qaza action is the first dashboard action.
- [x] Completion is visible above the fold without requiring scroll on the supported small-phone workspace viewport.
- [x] Completing a Qaza stays on Home and loads the next oldest pending record automatically.
- [x] Overall progress overview is preserved.
- [x] Today's progress is shown against a persisted daily target.
- [x] Daily target defaults to 5/day and is stored per active user.
- [x] Completion estimate accounts for today's remaining capacity.
- [x] View All opens the existing Qaza workspace rather than pushing a duplicate tracker screen.
- [x] English, Urdu, RTL, light/dark, accessibility and skeleton/loading patterns are respected.

## Current evidence

Existing Home already contained overall progress, prayer-level progress, skeleton loading, empty/error handling and a reusable per-prayer completion section. Task 10 fills the missing daily dashboard behavior and makes the primary completion action explicit and immediately accessible.

## Definition of Done

- [x] Implementation
- [x] Unit/widget tests
- [x] Regression tests
- [ ] Analyze
- [ ] CI
- [ ] Device QA where required
- [ ] UX review
- [x] Documentation
- [ ] Merge

## Evidence log

| Date | Status | Evidence |
|---|---|---|
| 2026-09-20 | Not started | Fresh tracking document created from the shared master plan. |
| 2026-09-21 | In Progress | PR #61 created from main. Implementation includes global oldest-first Home completion, daily progress aggregate, persisted per-user daily target, completion estimate, View All handoff, localization, and regression coverage. CI pending. |

**Rule:** update this tracking file, not the master plan, when status changes.

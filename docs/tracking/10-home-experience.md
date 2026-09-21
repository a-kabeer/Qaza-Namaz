# Home experience

**Priority:** P1  
**Status:** **Merged — Device QA Pending**

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
- [x] Deterministic ordering remains originalDate ASC, id ASC.
- [x] The primary Complete Next Qaza action is the first dashboard action.
- [x] The primary completion action is placed above the supporting dashboard information.
- [x] Completion is accessible without scrolling on the tested small-phone workspace viewport.
- [x] Completing a Qaza stays on Home and loads the next oldest pending record automatically.
- [x] Overall progress overview is preserved.
- [x] Today's progress is shown against a persisted daily target.
- [x] Daily target defaults to 5/day and is stored per active user.
- [x] Completion estimate accounts for today's remaining capacity.
- [x] View All opens the existing Qaza workspace rather than pushing a duplicate tracker screen.
- [x] English, Urdu, RTL, light/dark, accessibility and skeleton/loading patterns are respected.
- [x] Small-screen / large-text Home layout was hardened after CI exposed a real overflow.

## Current evidence

Existing Home already contained overall progress, prayer-level progress, skeleton loading, empty/error handling and a reusable per-prayer completion section. Task 10 completed the missing daily dashboard behavior and made the primary completion action explicit and immediately accessible.

### CI verification

Final Task 10 head: 8b495b24c409df4cd709a5cc8481af47efad0640

Final workflow: Flutter CI #1571

- [x] Analyze
- [x] Tests (Linux)
- [x] Tests (Windows)
- [x] Firestore security rules
- [x] Android debug and release artifacts

PR #61 was squash-merged after all five gates passed.

## Definition of Done

- [x] Implementation
- [x] Unit/widget tests
- [x] Regression tests
- [x] Analyze
- [x] CI
- [ ] Device QA where required
- [ ] UX review
- [x] Documentation
- [x] Merge

## Evidence log

| Date | Status | Evidence |
|---|---|---|
| 2026-09-20 | Not started | Fresh tracking document created from the shared master plan. |
| 2026-09-21 | In Progress | PR #61 created from main. Implementation included global oldest-first Home completion, daily progress aggregate, persisted per-user daily target, completion estimate, View All handoff, localization, and regression coverage. |
| 2026-09-21 | CI Fixes | Linux/Windows exposed a Home large-text overflow and a stale navigation regression. The overflow was traced to the daily-target dropdown expanding beyond its narrow layout; the selector was constrained and target labels were compacted. The five-item primary navigation test was aligned with the current Home/Qaza/Prayer Times/Knowledge/Settings navigation. |
| 2026-09-21 | Merged — Device QA Pending | Final CI run #1571 passed Analyze, Linux tests, Windows tests, Firestore security rules, and Android debug/release artifacts on head 8b495b24c409df4cd709a5cc8481af47efad0640. PR #61 merged as 9950d7df6bc5df5635569e2f44e4bb4fa2791cb1. |

**Rule:** update this tracking file, not the master plan, when status changes.
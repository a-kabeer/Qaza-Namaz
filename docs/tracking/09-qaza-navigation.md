# Qaza navigation & information architecture

**Priority:** P1  
**Status:** **Merged — Device QA Pending**

## Task checklist

- [x] Primary navigation Home / Qaza / Knowledge / Settings
- [x] Calculator from Home
- [x] Calculator from Qaza
- [x] Consistent FAB
- [x] Preserve tab state
- [x] Preserve scroll position
- [x] Prevent duplicate workspace routes
- [x] Android Back
- [x] Gesture Back
- [x] Predictive Back
- [x] Nested-flow Back

## Current evidence

Implemented in the workspace shell. Qaza is now a primary destination; Calculator remains contextual from Home/Qaza, and Prayer Times remains reachable from Settings.

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
| 2026-09-21 | Merged | PR #60 merged after all five CI gates passed on head `b610d7a3a559bbc2aeac6ca105305e24d4944def`; merge commit `2e200e2cb3a7a94b65e7373ad3ed365737ef5273`. Device QA and UX review remain pending. |

**Rule:** update this tracking file, not the master plan, when status changes.

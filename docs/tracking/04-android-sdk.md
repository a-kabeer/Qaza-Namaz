# Android target / SDK verification

**Priority:** P0  
**Status:** **Merged**

## Task checklist

- [x] Inspect resolved compile SDK
- [x] Inspect resolved target SDK
- [x] Meet current Google Play requirement
- [x] Add CI target-SDK assertion
- [x] Document min/target/compile SDK policy

## Current evidence

Implemented in PR #45 and merged to `main`. Android compile SDK and target SDK are explicitly pinned to API 36, and CI asserts the target SDK policy.

## Definition of Done

- [x] Implementation
- [x] Unit/widget tests — repository regression suite passed
- [x] Regression tests
- [x] Analyze
- [x] CI
- [x] Device QA where required — N/A for SDK policy verification
- [x] UX review — N/A for SDK configuration
- [x] Documentation
- [x] Merge

## Evidence log

| Date | Status | Evidence |
|---|---|---|
| 2026-09-20 | Implemented | API 36 compile/target policy and CI assertion added in PR #45. |
| 2026-09-20 | Merged | PR #45 merged to `main`; Android SDK policy is active. |

**Rule:** update this tracking file, not the master plan, when status changes.

# Firestore rules hardening

**Priority:** P0  
**Status:** **Merged**

## Task checklist

- [x] Validate exact document fields
- [x] Reject unexpected fields
- [x] Validate field types
- [x] Validate userId and record ID
- [x] Validate allowed prayer types
- [x] Validate pending/completed status
- [x] Validate completedAt consistency
- [x] Prevent immutable-field changes
- [x] Validate timestamps
- [x] Harden qazaChanges and syncMetadata
- [x] Add negative security tests

## Current evidence

Implemented in PR #45 and merged to `main` with merge commit `507e01c02e8ab726a5e3959ad1fe0bda2e9d7747`. Firestore rules include owner isolation, exact schemas, allowed prayer/status validation, completion consistency, timestamps, sync generation, qazaChanges, sync metadata, and generation-aware transitions. Positive and negative Firestore security coverage passed in CI.

## Definition of Done

- [x] Implementation
- [x] Unit/widget tests — covered by the repository regression suite/security-rule test coverage
- [x] Regression tests
- [x] Analyze
- [x] CI
- [x] Device QA where required — N/A for Firestore rule enforcement itself
- [x] UX review — N/A for backend rules
- [x] Documentation
- [x] Merge

## Evidence log

| Date | Status | Evidence |
|---|---|---|
| 2026-09-20 | Implemented | Firestore hardening implemented in PR #45. |
| 2026-09-20 | Merged | PR #45 merged to `main`; Firestore security tests passed in CI. |

**Rule:** update this tracking file, not the master plan, when status changes.

# Firestore rules hardening

**Priority:** P0  
**Status:** **Implemented**

## Task checklist

- [ ] Validate exact document fields
- [ ] Reject unexpected fields
- [ ] Validate field types
- [ ] Validate userId and record ID
- [ ] Validate allowed prayer types
- [ ] Validate pending/completed status
- [ ] Validate completedAt consistency
- [ ] Prevent immutable-field changes
- [ ] Validate timestamps
- [ ] Harden qazaChanges and syncMetadata
- [ ] Add negative security tests

## Current evidence

Rules smoke gate passed in earlier CI (#1444); final gate still depends on current CI and completion evidence.

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
| 2026-09-20 | Implemented | Fresh tracking document created from the shared master plan. |

**Rule:** update this tracking file, not the master plan, when status changes.

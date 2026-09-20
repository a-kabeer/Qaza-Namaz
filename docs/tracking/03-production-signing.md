# Production release signing

**Priority:** P0  
**Status:** **Implemented**

## Task checklist

- [ ] Configure production keystore
- [ ] Store signing secrets only in GitHub encrypted secrets
- [ ] Configure release signing
- [ ] Add SHA-1 and SHA-256 fingerprints
- [ ] Verify Firebase config against release certificate
- [ ] Build signed release AAB
- [ ] Verify AAB signature
- [ ] Upload release AAB in CI

## Current evidence

Release no longer falls back to the debug key. Signed AAB is blocked until production signing secrets are available.

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

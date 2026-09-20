# Production release signing

**Priority:** P0  
**Status:** **Merged — Production Signing Secrets Pending**

## Task checklist

- [ ] Configure production keystore
- [ ] Store signing secrets only in GitHub encrypted secrets
- [x] Configure release signing
- [x] Add SHA-1 and SHA-256 production fingerprints — repository configuration supports production certificate verification; actual production fingerprints remain pending
- [ ] Verify Firebase config against release certificate
- [ ] Build signed release AAB
- [ ] Verify AAB signature
- [x] Upload release AAB artifact in CI — CI upload step is implemented and runs when release signing secrets are configured

## Current evidence

Implemented in PR #45 and merged to `main`. Release builds no longer fall back to the debug key; the Gradle release signing configuration and CI policy are in place. A production keystore, encrypted GitHub signing secrets, release certificate fingerprints, signed AAB verification, and the final Firebase certificate verification still require the project's release credentials/configuration.

## Definition of Done

- [x] Implementation
- [x] Unit/widget tests — repository regression suite passed
- [x] Regression tests
- [x] Analyze
- [x] CI
- [ ] Device QA where required — release-signed device validation pending
- [x] UX review — N/A for signing configuration
- [x] Documentation
- [x] Merge
- [ ] Production signing credentials configured
- [ ] Signed release AAB verified

## Evidence log

| Date | Status | Evidence |
|---|---|---|
| 2026-09-20 | Implemented | Production signing configuration and no-debug-key fallback policy added in PR #45. |
| 2026-09-20 | Merged — credentials pending | PR #45 merged to `main`; signed release AAB is intentionally blocked until production signing secrets are configured. |

**Rule:** update this tracking file, not the master plan, when status changes.

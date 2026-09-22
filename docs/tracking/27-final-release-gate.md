# Final release gate

**Priority:** P0  
**Status:** **Blocked — External Configuration**

_Reconciled 2026-09-22 against `main` @ 505a828. Automated gates pass on `main` (CI green: Analyze, Tests Linux/Windows, security rules, Android artifacts). The gate remains blocked on two things that cannot be satisfied from the repository: App Check / Google Sign-In registration of the release signing SHA in the Firebase console (task 02), and the connected-device QA passes listed below, none of which have been performed against current `main`._

## Task checklist

Automated, verified on `main` @ 505a828:

- [x] Firestore rules hardened — `security_rules` CI job
- [x] Security tests pass — same job
- [x] Production signing works — CI publishes `app-release-apk-signed`
- [x] Signed AAB — CI publishes `app-release-aab`
- [x] Target SDK verified — `targetSdk=36` on the connected device
- [x] Backup strategy finalized — `fullBackupContent` + `dataExtractionRules`
- [x] English localization — `app_en.arb`
- [x] Urdu localization — `app_ur.arb`
- [x] Documentation updated — this reconciliation

Blocked on external configuration:

- [ ] App Check configured — needs the release signing SHA registered in the
      Firebase console (task 02)
- [ ] Crash reporting — nothing exists (task 23)
- [ ] Privacy policy
- [ ] Terms
- [ ] Account/data deletion process

Blocked on device QA — none performed against current `main`:

- [ ] Notification device QA
- [ ] Google Sign-In device QA
- [ ] Guest migration device QA
- [ ] Import/export QA
- [ ] RTL QA
- [ ] Accessibility QA
- [ ] Large dataset QA
- [ ] Release checklist signed off

## Current evidence

Release is blocked until every required gate is satisfied.

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
| 2026-09-20 | Blocked | Fresh tracking document created from the shared master plan. |

**Rule:** update this tracking file, not the master plan, when status changes.

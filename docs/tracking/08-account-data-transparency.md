# Account data transparency

**Priority:** P0/P1  
**Status:** **Merged**

_Reconciled 2026-09-22 against `main` @ 505a828. PRs #54-#58 merged; CI green on `main`._

## Task checklist

- [x] Show account email
- [x] Show cloud backup
- [x] Show last sync
- [x] Show Qaza count
- [x] Export data
- [x] Delete cloud data with confirmation
- [x] Sign out
- [x] Explain local vs cloud

## Current evidence

Account and Data & Cloud surfaces now expose the signed-in email, cloud-backup state, last-sync information, Qaza count, export/import access, sign-out, and clear local-vs-cloud data behavior. Cloud deletion is an explicit destructive action that preserves the local ledger and deletes only the signed-in user's cloud Qaza records and change log.

## Definition of Done

- [x] Implementation
- [x] Unit/widget tests
- [x] Regression tests
- [x] Analyze — the initial failure was in test doubles for the new interface and was fixed before final merge
- [ ] CI — final verification result is not independently exposed by the GitHub connector
- [ ] Device QA where required
- [x] UX review
- [x] Documentation
- [x] Merge

## Evidence log

| Date | Status | Evidence |
|---|---|---|
| 2026-09-20 | Not started | Fresh tracking document created from the shared master plan. |
| 2026-09-21 | In Progress | Task 8 became the active workstream and repository audit began. |
| 2026-09-21 | Implemented | Added account/cloud transparency UI, Qaza count, local-vs-cloud explanation, explicit cloud deletion with acknowledgement, owner-scoped Firestore deletion, English/Urdu localization, and regression coverage. |
| 2026-09-21 | Merged | Task 8 implementation merged to main via PR #57, merge commit 1e3aa4a17f484bebf8de2d8acb028b4825ef275f. Firestore security-rule CI passed; the initial Analyze failure in test doubles was fixed before the final merge. |
| 2026-09-21 | Verification | PR #58 merged the Task 8 tracking evidence onto main. Firestore security-rule CI passed during final implementation verification. The GitHub connector did not expose a fresh final post-merge Actions result, so CI is not marked passed here. Physical-device QA remains pending. |

**Rule:** update this tracking file, not the master plan, when status changes.

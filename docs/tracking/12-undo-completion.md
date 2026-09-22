# Undo completion

**Priority:** P1  
**Status:** **Merged**

_Reconciled 2026-09-22 against `main` @ 505a828. PR #65. `qaza_undo_repository.dart`, `qaza_undo_service.dart` and `qaza_undo_banner.dart`, with two dedicated test files._

## Task checklist

- [x] Reversible completion state
- [x] Single completion undo
- [x] Bulk completion undo
- [x] Persist undo window
- [x] Offline/online tests

## Current evidence

Undo must not silently delete or corrupt records.

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

**Rule:** update this tracking file, not the master plan, when status changes.

### Implementation evidence
- Persistent 10-second undo metadata is stored per user and is automatically retired after expiry.
- Single and bulk completion surfaces expose an Undo action through the Home, Complete Qaza, and Tracker flows.
- Undo is guarded by the exact completion timestamp plus the record's last-update timestamp, so later edits/conflicts are not overwritten.
- Offline undo updates the local Drift ledger immediately and queues an update operation for later cloud sync.
- Firestore rules now allow only a newer completed-to-pending transition with `completedAt == null`; existing completion protections remain intact.
- Added focused persistence, stale-action, later-edit, bulk, and offline sync regression coverage.

### Evidence log
| Date | Status | Evidence |
|---|---|---|
| 2026-09-21 | Merged — Device QA Pending | PR #65 merged by squash as `6493ddc8ba271bd757d823a0607bb9673aff2e32`; final CI run #1615 passed all five required gates. Physical-device QA and UX review remain pending. |

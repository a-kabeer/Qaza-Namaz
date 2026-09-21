# Undo completion

**Priority:** P1  
**Status:** **In progress**

## Task checklist

- [x] Reversible completion state
- [x] Single completion undo
- [x] Bulk completion undo
- [x] Persist undo window
- [x] Offline/online tests

## Current evidence

Undo must not silently delete or corrupt records.

## Definition of Done

- [ ] Implementation
- [x] Unit/widget tests
- [x] Regression tests
- [ ] Analyze
- [ ] CI
- [ ] Device QA where required
- [ ] UX review
- [x] Documentation
- [ ] Merge

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
| 2026-09-21 | In progress | Implementation and focused tests added on `task-12/undo-completion`; CI and merge still pending. |

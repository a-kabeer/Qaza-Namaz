# Qaza Namaz — Offline-First Architecture

## Task 5 scope

This document records the dedicated Offline-First Architecture audit. The existing local-first repository, SharedPreferences cache, and synchronization engine are preserved; only concrete weaknesses identified by the audit are changed.

## Audited architecture

The current flow is:

`UI -> QazaService -> OfflineFirstQazaRepository -> QazaLocalStore -> FirestoreQazaRepository`

The offline-first repository keeps reads local, applies writes to the local cache first, persists pending remote work in an outbox, and synchronizes in the background.

### Local behavior

- Reads are served from the active user's local cache and do not require network access.
- Adds and completions update local state before background synchronization.
- Pending operations survive repository recreation through the persisted outbox.
- Cache data and outbox operations are namespaced by Firebase UID.
- Account switching drains the in-flight sync before loading another user's namespace.

## Bidirectional synchronization audit

### Local -> Firestore

Verified behavior:

1. Local writes are persisted before remote synchronization.
2. Add operations are queued with stable operation IDs.
3. Completion operations are queued with stable record IDs.
4. Failed remote writes remain in the outbox with an incremented attempt count.
5. Confirmed operations are removed from the outbox only after the remote call succeeds.
6. Stable record IDs make repeated adds duplicate-safe.

### Firestore -> local

Verified behavior:

1. Pull synchronization reads the remote user's records after the local outbox is flushed.
2. Remote-only records are inserted into the local cache.
3. Remote completion is merged forward-only into a locally pending record.
4. A locally completed record whose remote copy is still pending is re-queued for completion.
5. Local-only records are never deleted by a remote pull.

## Multi-device and conflict audit

The audit identified one real weakness in the previous implementation: the local merge policy declared that the earliest `completedAt` should win, but Firestore previously ignored a completion request when the document was already completed. That allowed one device to retain an earlier completion time while Firestore and another device retained a later time.

### Fix applied

`FirestoreQazaRepository.completeRecords` now keeps completion forward-only while applying a deterministic earliest-completion rule:

- pending -> completed is applied;
- completed + later/equal completion is a no-op;
- completed + earlier completion updates `completedAt` to the earlier value.

This makes the backend canonical value converge with the local merge policy across devices.

## Reliability audit

The existing engine already provides:

- single-flight synchronization;
- retry by retaining failed outbox operations;
- persisted outbox recovery after repository recreation;
- connectivity-triggered retry;
- deterministic UID isolation;
- explicit sync states for offline, syncing, synced, pending, and error conditions.

No additional repository or database layer was warranted by the audit.

## Validation added

The existing offline-first test suite was extended to cover:

- local -> remote synchronization;
- remote -> local synchronization;
- multi-device remote changes;
- conflicting completion timestamps;
- convergence on the earliest completion timestamp;
- empty pending outboxes after successful convergence.

The in-memory test repository was aligned with the production conflict policy so the multi-device test exercises the same deterministic rule.

## Outcome

The local-first repository and synchronization engine remain in place. Only the verified multi-device completion conflict weakness was fixed.

Task 5 is complete only after the repository CI validation confirms analysis and the full test suite pass.

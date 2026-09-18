# Qaza Namaz — Offline-First Architecture

## Current architecture

The local production source of truth is **Drift/SQLite**. SharedPreferences
holds settings (theme, language, calculator inputs, reminder preferences, the
one-shot migration flag) and is never a Qaza persistence layer.

The flow is:

`UI -> Riverpod controller -> QazaService -> OfflineFirstQazaRepository -> QazaLocalStore (Drift) -> FirestoreQazaRepository`

## Startup: bootstrap and hydration

A signed-in account whose local database is empty must not be mistaken for an
account with no Qaza. `OfflineFirstQazaRepository` therefore runs an explicit
startup lifecycle on every `setActiveUser`:

```text
signed in -> BOOTSTRAPPING -> (local database empty?) -> HYDRATING -> READY
```

- `BOOTSTRAPPING` — the local database is being opened for this account.
- `HYDRATING` — the local database was empty, so remote records are being
  pulled before the ledger is treated as complete.
- Ready — any other state (`synced`, `pendingSync`, `offline`, `syncError`).
  `SyncState.isReady` is the single check.

`ensureHydrated()` gates `getPage`, `getRecords`, `getOldestPending`,
`getHistoryPage` and `getProgressSummary`, so **availability and duplicate
calculations can never observe a partially hydrated ledger** and wrongly
conclude that a date is free.

Every path terminates in a ready state: an offline start, an empty cloud
account, a failed pull and an interrupted pull all continue offline-first from
whatever is local, and retry on the next sync. An account switch supersedes any
in-flight bootstrap through the session generation counter.

User-facing wording for these states is `Setting up` and `Restoring`; Firestore,
outbox, DAO and repository never appear in the UI.

Covered by `test/cloud_bootstrap_test.dart`.

## Audited architecture

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

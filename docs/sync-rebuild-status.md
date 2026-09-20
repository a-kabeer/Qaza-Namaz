# Qaza Namaz — Sync Rebuild & Hardening Status

Branch: `rebuild/firestore-sync-hardening`
PR: #40 — Rebuild Firebase sync for large Qaza ledgers

## Overall

The sync subsystem has been structurally rebuilt on a dedicated branch. The application/domain architecture outside synchronization has been left intact.

| Phase | Status | Implementation |
|---|---|---|
| 1. Firestore repository internals | ✅ Implemented | Bounded 400-op WriteBatch transport; change-log events; reset metadata |
| 2. Sync outbox | ✅ Implemented | Bounded dequeue/remove APIs; transactional append + queue; durable retry metadata |
| 3. Sync engine | ✅ Implemented | Dedicated single-flight sync engine; session-safe lifecycle; bounded processing |
| 4. Remote incremental sync | ✅ Implemented | Cursor-based `qazaChanges` reconciliation; paginated change reads |
| 5. Batch completion | ✅ Implemented | Completion snapshots flow through batched sync operations |
| 6. Batch reset | ✅ Implemented | 400-op delete batches; resumable reset operation IDs; generation barrier |
| 7. Retry strategy | ✅ Implemented | Firebase transient-error classification; exponential backoff; durable attempts/errors |
| 8. Sync state | ✅ Implemented | Syncing/retrying/partial/synced/offline/error + progress counters |
| 9. Large-data stress testing | 🔄 In progress | 13,000-record engine stress/regression coverage added; full CI validation pending |
| 10. Final CI / cross-platform validation | 🔄 In progress | Flutter CI run active; Linux, Windows, Android and Analyze jobs present |

## Changes

- `FirestoreQazaRepository` now sends normal bulk mutations through bounded Firestore write batches instead of record-by-record transactions.
- `QazaSyncEngine` owns queue flushing, incremental reconciliation, retry scheduling, reset recovery, and sync progress.
- `SyncOutboxDao` supports bounded reads/deletes instead of rebuilding the whole queue after each remote write.
- `qazaChanges` provides a durable remote change stream per user.
- `syncMetadata/state` carries reset generation/barrier information.
- Firestore rules block record create/update operations while a reset is active.
- Incremental-sync indexes are declared in `firestore.indexes.json`.
- Existing guest migration completion operations now carry completed record snapshots so they use the new batched sync path.

## Large-data target

Test sizes:
- 1,000
- 5,000
- 13,000+
- 20,000
- 50,000

The added engine stress test verifies that 13,000 pending operations are processed in 400-operation batches, not as 13,000 individual network operations, and that the local outbox is drained without whole-queue persistence rewrites.

## Remaining validation

1. Flutter analyze
2. Linux tests
3. Windows tests
4. Android debug/release build
5. Drift code generation
6. Full sync test suite
7. Failure/restart/offline recovery
8. Real Firebase 13,000-record smoke test
9. Multi-user isolation test

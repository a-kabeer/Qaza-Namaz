# Qaza Namaz — Sync Rebuild & Hardening Status

Branch: `rebuild/firestore-sync-hardening`
PR: #40 — Rebuild Firebase sync for large Qaza ledgers
Latest implementation commit: `8300617428391c0029ba0a2f0d250207a08fd73f`
Latest CI run: #1382 (in progress)

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
| 9. Large-data stress testing | 🔄 In progress | 13,000-record engine stress/regression coverage plus 1,000-operation completion coverage added; 20k/50k and real-Firebase smoke validation remain |
| 10. Final CI / cross-platform validation | 🔄 In progress | Latest CI run is being queued/processed; previous run 1367 was cancelled by subsequent branch updates |

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

## Latest validation update

CI run #1374 exposed these issues, which have now been corrected on the branch:
- missing Drift row-to-domain mapper in the new ID lookup
- retry-attempt type inference error
- non-exhaustive `SyncStatus.idle` switches
- malformed placement of the completion stress test
- reset-generation protection was strengthened after the first validation pass

CI run #1382 is now validating the corrected head across Android, Linux, Windows, and Analyze.

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

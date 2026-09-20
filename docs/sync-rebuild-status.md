# Qaza Namaz — Sync Rebuild & Hardening Status

Branch: `rebuild/firestore-sync-hardening`

## Overall
- [x] Scope locked to synchronization subsystem only
- [ ] Firestore repository internals
- [ ] Sync outbox
- [ ] Sync engine
- [ ] Remote incremental sync
- [ ] Batch completion
- [ ] Batch reset
- [ ] Retry strategy
- [ ] Sync state
- [ ] Large-data stress testing
- [ ] Final CI / cross-platform validation

## Tracking

| Phase | Status | Notes |
|---|---|---|
| 1. Firestore repository internals | 🔄 In progress | Replacing single-record bulk transport with bounded WriteBatch operations |
| 2. Sync outbox | ⏳ Pending | Replace whole-queue rewrites with bounded dequeue/delete |
| 3. Sync engine | ⏳ Pending | Dedicated bounded batch processing and single-flight coordination |
| 4. Remote incremental sync | ⏳ Pending | Add durable change-log based incremental reconciliation |
| 5. Batch completion | ⏳ Pending | Completion snapshots synchronized in batches |
| 6. Batch reset | ⏳ Pending | Reset barrier + resumable bounded deletion |
| 7. Retry strategy | ⏳ Pending | Backoff, retry classification, durable failures |
| 8. Sync state | ⏳ Pending | Accurate pending/processed/error/retry states |
| 9. Large-data stress testing | ⏳ Pending | 1k / 5k / 13k / 20k / 50k scenarios |

## Success Criteria
- Bulk cloud writes use bounded Firestore batches.
- The outbox is never rewritten in full after every operation.
- Sync survives restart and offline periods.
- Normal synchronization consumes change-log pages instead of the full ledger.
- Completion and reset are batch-based and idempotent.
- Reset cannot resurrect stale local operations.
- Failed batches remain durable and retry independently.
- Sync state never reports success while cloud work remains.
- Large-ledger stress tests cover at least 13,000 records and multi-user isolation.

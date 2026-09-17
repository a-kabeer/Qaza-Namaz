# SharedPreferences → Drift/SQLite Migration Status

## Migration scope

Production migration of the Qaza local persistence layer from the legacy SharedPreferences snapshot to Drift/SQLite while preserving the offline-first repository, Firebase ownership model, and existing domain behavior.

CI/build validation is intentionally deferred until **Part 13**. Parts 1–12 are implemented and reviewed incrementally without using CI as an intermediate gate.

## Status

- Part 1 — ✅ COMPLETE — Drift foundation
- Part 2 — ✅ COMPLETE — Qaza records schema
- Part 3 — ✅ COMPLETE — Drift DAO layer
- Part 4 — ✅ COMPLETE — Repository integration
- Part 5 — ✅ COMPLETE — Persistent sync/outbox
- Part 6 — ✅ COMPLETE — Authentication lifecycle and per-user isolation
- Part 7 — ✅ COMPLETE — Production bounded read paths
- Part 8 — ⏳ PENDING — Mutation and transaction hardening
- Part 9 — ⏳ PENDING — Large-dataset Home/Logs performance integration
- Part 10 — ⏳ PENDING — Migration cleanup and legacy-store retirement
- Part 11 — ⏳ PENDING — Data migration/upgrade resilience
- Part 12 — ⏳ PENDING — Final application-level regression audit
- Part 13 — ⏳ PENDING — Full GitHub CI/build validation and completion gate

## Part 7 — Production bounded read paths

Completed on `task-db-1-drift-foundation`.

- Added repository-level `QazaPage` keyset pagination with UID, prayer, and status filters.
- Added repository-level oldest-pending lookup so completion flows do not need to scan the ledger.
- Drift repository now uses the existing indexed keyset DAO for bounded reads; its legacy `getRecords()` compatibility API is implemented by controlled page iteration rather than SQL offsets.
- Offline-first repository routes normal paginated, oldest-pending, history, and aggregate reads directly to the UID-scoped local store without materializing the legacy snapshot.
- Qaza service progress calculations now use database-backed aggregate summaries.
- Selected-record completion validation iterates bounded pending pages instead of loading the complete ledger in one request.
- Namaz-wise pending-date UI now loads 50 records at a time with explicit Load more behavior, preventing 1,000+ pending records from being rendered at once.
- Firestore repository received matching bounded page/oldest-pending contracts for repository parity.
- Added regression coverage for 1,001-record keyset paging, oldest-pending lookup, service delegation, aggregate progress, and zero-snapshot bounded reads.

## Legacy compatibility boundary

`DriftQazaLocalStore.load()` remains available only for legacy full-snapshot compatibility and explicit legacy APIs. New production scalable read paths use `getPage`, `getHistoryPage`, `getOldestPending`, or `getProgressSummary`. Part 10 will retire the remaining compatibility path after migration callers are fully removed.

## Validation policy

No Part 13 CI gate is claimed for Parts 1–12. Final completion requires the complete configured GitHub CI/build matrix to pass after Part 13.

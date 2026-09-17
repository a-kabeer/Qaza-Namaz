# SharedPreferences → Drift/SQLite Migration Status

## Migration scope
Production migration of Qaza local persistence from the legacy SharedPreferences snapshot to Drift/SQLite while preserving offline-first behavior, Firebase ownership, and domain behavior.

CI/build validation is intentionally deferred until **Part 13**.

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
- Added repository-level `QazaPage` keyset pagination with UID, prayer, and status filters.
- Added repository-level oldest-pending lookup.
- Drift uses the indexed keyset DAO; legacy full-ledger reads iterate bounded pages rather than SQL offsets.
- Offline-first paginated, oldest-pending, history, and aggregate reads bypass the legacy full snapshot.
- Service progress and oldest-pending operations use database-backed/bounded paths.
- Namaz-wise pending dates load 50 records at a time with Load more.
- Firestore implements matching bounded contracts for repository parity.
- Added regression coverage for 1,001-record paging and bounded reads.

## Legacy compatibility boundary
`DriftQazaLocalStore.load()` remains only for legacy full-snapshot compatibility and explicit legacy APIs. Part 10 will retire the remaining compatibility path after migration callers are fully removed.

## Validation policy
No Part 13 CI gate is claimed for Parts 1–12. Final completion requires the complete configured GitHub CI/build matrix to pass after Part 13.

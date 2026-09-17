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

Implemented on `task-db-1-drift-foundation`.

- Repository-level keyset pagination and oldest-pending contracts are available.
- Drift reads use indexed keyset pagination and direct oldest-pending lookup.
- Offline-first bounded reads bypass `DriftQazaLocalStore.load()`.
- Service progress and oldest-pending operations use bounded/database-backed paths.
- Selected-record validation iterates bounded pending pages.
- Namaz-wise pending dates render 50 records per page with Load more.
- Firestore provides matching bounded read contracts.
- Regression coverage includes a 1,001-record ledger and zero-snapshot bounded reads.

## Legacy compatibility boundary
`DriftQazaLocalStore.load()` remains only for legacy full-snapshot compatibility. Part 10 will retire this final compatibility path after all remaining migration callers are removed.

## Validation policy
No Part 13 CI gate is claimed for Parts 1–12. Final completion requires the complete configured GitHub CI/build matrix to pass after Part 13.

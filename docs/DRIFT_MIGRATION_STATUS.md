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
- Part 8 — ✅ COMPLETE — Mutation and transaction hardening
- Part 9 — ✅ COMPLETE — Large-dataset Home/Logs performance integration
- Part 10 — ✅ COMPLETE — Migration cleanup and legacy-store retirement
- Part 11 — ✅ COMPLETE — Data migration/upgrade resilience
- Part 12 — ⏳ PENDING — Final application-level regression audit
- Part 13 — ⏳ PENDING — Full GitHub CI/build validation and completion gate

## Part 11 — Data migration/upgrade resilience

Implemented on `task-db-1-drift-foundation`.

- Serialized concurrent migration calls within the application process.
- Added explicit migration version validation and rejected unsupported future marker versions.
- Hardened legacy JSON shape/type validation; malformed snapshots fail safely without setting completion state.
- Kept all target inserts and conflict checks inside one Drift transaction so failures cannot leave partial imports.
- Preserved user isolation checks and added per-user target-count verification.
- Migration/version markers are written only after successful database work and verification.
- Re-running a successfully completed migration is a safe no-op.
- Added regression coverage for fresh installs, legacy import, duplicate normalization, idempotency, malformed data, isolation mismatches, existing-row conflicts, and unsupported marker versions.

## Part 10 — Migration cleanup and legacy-store retirement

Implemented on `task-db-1-drift-foundation`.

- `DriftQazaLocalStore` is now the only production Qaza local-store implementation.
- The application runtime no longer constructs or imports the SharedPreferences local store.
- The retired SharedPreferences local-store source file was removed.
- SharedPreferences remains isolated to the one-time legacy migration bootstrap so existing installations can still upgrade.
- The migration marker and target verification remain in place so a completed migration is not repeated.
- Runtime last-sync state no longer depends on the legacy SharedPreferences store.

## Remaining legacy boundary
The only remaining SharedPreferences usage is the one-time migration bootstrap. Part 12 will audit remaining full-snapshot compatibility paths, database lifecycle/upgrade behavior, and application-level regressions before Part 13 CI/build validation.

## Validation policy
No Part 13 CI gate is claimed for Parts 1–12. Final completion requires the complete configured GitHub CI/build matrix to pass after Part 13.

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
- Part 7 — ⏳ PENDING — Production read-path migration / remove legacy full-ledger dependencies
- Part 8 — ⏳ PENDING — Mutation and transaction hardening
- Part 9 — ⏳ PENDING — Large-dataset Home/Logs performance integration
- Part 10 — ⏳ PENDING — Migration cleanup and legacy-store retirement
- Part 11 — ⏳ PENDING — Data migration/upgrade resilience
- Part 12 — ⏳ PENDING — Final application-level regression audit
- Part 13 — ⏳ PENDING — Full GitHub CI/build validation and completion gate

## Part 6 — Authentication lifecycle and per-user isolation

Completed on `task-db-1-drift-foundation`.

- Added an authentication-session generation boundary to the offline-first repository.
- Account switches invalidate stale asynchronous reads, writes, and synchronization work.
- Sign-out clears the in-memory ledger, outbox, last-sync state, and active UID.
- Local reads remain explicitly UID-scoped.
- Local writes reject records whose `userId` does not match the active session.
- Outbox processing validates operation ownership before remote replay.
- Remote pull validates every returned record against the active Firebase UID.
- Added regression tests for account switching, sign-out isolation, cross-account writes, and lazy authentication startup.

## Important remaining migration risk

`DriftQazaLocalStore.load()` is retained as a compatibility/legacy full-snapshot path. It still materializes all users when called. Normal paginated/history/progress paths already use UID-scoped Drift queries, but Part 7 must remove remaining production dependencies on this full-ledger compatibility path before the migration can be considered complete.

## Validation policy

No Part 13 CI gate is claimed for Parts 1–12. Final completion requires the complete configured GitHub CI/build matrix to pass after Part 13.

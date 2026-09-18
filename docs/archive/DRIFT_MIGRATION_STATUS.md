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
- Part 12 — ✅ COMPLETE — Final application-level regression audit
- Part 13 — ⏳ PENDING — Full GitHub CI/build validation and completion gate

## Part 12 — Final application-level regression audit

Implemented on `task-db-1-drift-foundation`.

- Audited production read paths for bounded ledger pages, direct oldest-pending lookup, history pagination, aggregate progress, completion, duplicate protection, and strict user scoping.
- Added final regression coverage using a 5,000-record ledger to protect large-dataset behavior.
- Added multi-page history coverage and cross-user isolation checks.
- Added complete-oldest workflow coverage to verify the intended prayer record is changed.
- Added duplicate protection and cross-account mutation coverage.
- Expanded migration regression coverage for concurrent bootstrap calls and timezone-aware legacy calendar dates.
- Migration now canonicalizes legacy `originalDate` values as calendar dates before deduplication/persistence, matching the app's date-only Qaza semantics.
- Existing database schema/index coverage, migration resilience coverage, dashboard aggregate coverage, history pagination coverage, and offline-first lazy-loading coverage remain represented by dedicated tests.
- No production UI or database architecture was duplicated from the dedicated migration/Home workstreams.

## Remaining legacy boundary
SharedPreferences remains only at the one-time migration bootstrap required for existing installations. The runtime Qaza local store is Drift/SQLite-backed.

The repository still contains an intentional legacy full-ledger compatibility API (`getRecords`) for compatibility/data-transfer paths; new scalable UI paths use bounded keyset/history APIs. This compatibility path is not used by the production Dashboard/History bounded reads.

## Validation policy
No Part 13 CI gate is claimed for Parts 1–12. Final completion requires the complete configured GitHub CI/build matrix to pass after Part 13.

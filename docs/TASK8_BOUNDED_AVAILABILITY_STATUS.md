# Task 8 — Bounded Availability Query Status

## Completed

- [x] Moved `QazaService.analyzeAvailability()` off the legacy full-ledger read path.
- [x] Moved `QazaService.recordQazaForDates()` off the legacy full-ledger read path.
- [x] Availability queries normalize dates before querying.
- [x] Queries are constrained to the minimum/maximum selected date and selected prayer types.
- [x] Queries are paginated with a bounded page size of 500.
- [x] User isolation remains enforced by the repository/data-source query.
- [x] Existing pending and completed records remain protected as recorded combinations.
- [x] Witr remains an independent prayer combination.
- [x] Add Qaza now uses the shared bounded service path.
- [x] Existing Drift indexes already cover user/date and user/prayer/date access patterns, so no schema-version bump was required.

## Remaining

- [ ] Add dedicated DAO/repository performance tests proving a large unrelated ledger does not get materialized for availability checks.
- [ ] Complete calendar date-level availability UI: disable a date only when every prayer is unavailable; keep unavailable prayers independent.
- [ ] Full CI and generated-code validation — final Task 13 gate.

## Architecture

The legacy `getRecords()` API remains available for legacy/detail screens that explicitly need the complete ledger. Availability and Add Qaza no longer depend on it.

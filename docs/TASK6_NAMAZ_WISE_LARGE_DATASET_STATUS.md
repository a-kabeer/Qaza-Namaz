# Task 6 — Namaz-wise / Pending List Large-Dataset Status

## Scope
Audit the Namaz-wise navigation and pending-date list after the Drift migration, with focus on 1,000+ records.

## Completed

- [x] Namaz-wise screen contains only the six prayer navigation cards; it does not load the ledger.
- [x] Pending Dates uses repository `getPage()` with a bounded page size of 50.
- [x] Keyset pagination uses `originalDate + id` cursors.
- [x] Prayer and `pending` filters are pushed to the repository/database query.
- [x] Initial screen load does not call the legacy full-ledger `getRecords()` API.
- [x] Load-more is explicit and bounded; large ledgers are not eagerly materialized.
- [x] Multi-select operates only on records currently loaded into the screen.
- [x] Completion delegates selected IDs to the service's bounded validation path.
- [x] After completion, the screen reloads from the first bounded page.
- [x] No SharedPreferences runtime persistence was introduced.

## Design note

The screen may accumulate records if the user explicitly presses **Load more** repeatedly. This is intentional for multi-selection: the user can select across loaded pages. It is not an eager full-ledger load. A future virtualized selection model could reduce memory further, but is outside this reconciliation task.

## Remaining

- [ ] Final CI / build / test gate (Task 13)

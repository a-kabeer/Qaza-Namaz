# Task 4 — Home / Drift Reconciliation Status

## Baseline

This reconciliation is based on `reconcile/pr16-drift`, directly based on the current `main` / Drift baseline.

## Rules

- Home statistics use the database-backed `progressSummaryProvider`.
- Home does not materialize `loadedRecordsProvider` for summary or prayer counts.
- Detailed Qaza lists remain independently paginated.
- SharedPreferences is not restored as a runtime persistence layer.

## Completed

- [x] Home redesign reconciled into the Drift baseline
- [x] Home overall progress migrated to database-backed progress summary
- [x] Home prayer counts migrated to database-backed progress summary
- [x] Full-ledger Home read removed
- [x] Workspace Dashboard navigation replaced by Home

## Remaining

- [ ] Completion screen audit (Task 5)
- [ ] Full CI — final Task 13 gate

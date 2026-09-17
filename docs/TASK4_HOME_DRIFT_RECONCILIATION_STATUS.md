# Task 4 — Home / Drift Reconciliation Status

## Baseline

This reconciliation is based on `reconcile/pr16-drift`, which is directly based on the current `main` / Drift baseline.

## Rules

- Home statistics must use the database-backed `progressSummaryProvider`.
- Home must not materialize `loadedRecordsProvider` for summary or prayer counts.
- Detailed Qaza lists remain independently paginated.
- SharedPreferences is not restored as a runtime persistence layer.

## Status

- [ ] Home redesign imported from PR #19
- [ ] Home overall progress migrated to database-backed progress summary
- [ ] Home prayer counts migrated to database-backed progress summary
- [ ] Full-ledger Home read removed
- [ ] Full CI — final Task 13 gate

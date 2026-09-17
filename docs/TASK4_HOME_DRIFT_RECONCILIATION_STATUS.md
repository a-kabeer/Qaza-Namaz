# Task 4 — Home / Drift Reconciliation Status

## Baseline

This reconciliation is based on `reconcile/pr16-drift`, directly based on the current `main` / Drift baseline.

## Completed

- [x] Home redesign reconciled into the Drift baseline
- [x] Home overall progress migrated to database-backed progress summary
- [x] Home prayer counts migrated to database-backed progress summary
- [x] Full-ledger Home read removed
- [x] Workspace Dashboard navigation replaced by Home
- [x] Completion flow audited and moved to bounded oldest-pending lookup
- [x] Completion mutation now targets the resolved record directly
- [x] Completion refresh invalidates bounded oldest lookup and aggregate progress only
- [x] Regression contract tests added

## Architecture guardrails

- Home summary screens use `progressSummaryProvider`.
- Completion UI uses `oldestPendingProvider` and does not materialize `loadedRecordsProvider`.
- Detailed ledger/history screens remain independently paginated.
- SharedPreferences is not restored as a runtime persistence layer.

## Remaining

- [ ] Full CI — final Task 13 gate

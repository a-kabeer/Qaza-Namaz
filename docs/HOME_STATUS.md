# Home Status

## Current baseline

Home is reconciled with the Drift/SQLite production architecture.

## Production read path

`Home UI → progressSummaryProvider → QazaService → QazaRepository → Drift/SQLite aggregate DAO`

Home does not load the complete Qaza ledger to render summary information.

## Completed

- Database-backed overall progress.
- Database-backed prayer-wise progress.
- Bounded completion entry points.
- Refresh/invalidation of aggregate and oldest-pending state after mutations.
- No runtime SharedPreferences ledger dependency.
- Reconciled Home work from PR #19 against the PR #17 Drift baseline.

## Regression coverage

Home/progress and large-ledger bounded-read behavior are covered by the existing regression suite. Final execution is part of Task 13's complete CI gate.

## Reconciliation note

PR #17 is the merged baseline. PR #16 and PR #19 are being reconciled on `reconcile/pr16-drift`; their overlapping Home/database implementations are not treated as independent production architectures.

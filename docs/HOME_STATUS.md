# Home / Dashboard Redesign Status

## Task
Convert the current Dashboard into a task-focused Home experience centered on the real user journey:

- New user: Calculate Qaza or Add Qaza → save → return to Home.
- Existing user: Home → see pending Qaza → Complete Qaza → progress updates → return to Home.
- Keep Home lightweight and database-backed so large ledgers do not require the full record set to be loaded.

## Overall Status
IN PROGRESS

## Implementation Parts

| Part | Task | Status |
|------|------|--------|
| 1 | Baseline & PR Reconciliation | ✅ Complete |
| 2 | Home Architecture & State Model | ✅ Complete |
| 3 | Dashboard → Home Rename | ✅ Complete |
| 4 | Home Header | ✅ Complete |
| 5 | New User / Empty Home | ✅ Complete |
| 6 | Active User Home | ✅ Complete |
| 7 | Progress & Prayer Summary | ✅ Complete |
| 8 | Complete Qaza UX | ✅ Complete |
| 9 | Large Dataset / Database Performance | 🟡 Ready / blocked by DB migration |
| 10 | Theme, RTL & Responsive UX | ⬜ Pending |
| 11 | Navigation & Regression Testing | ⬜ Pending |
| 12 | Final Validation, Documentation & CI | ⬜ Pending |

## Part 7 — Progress & Prayer Summary

### Completed
- Added one cohesive `Your progress` card to active and all-completed Home states.
- Reused centralized overall and prayer progress providers.
- Displayed only prayers with existing records to keep the summary compact.
- Reused theme-aware progress widgets.
- UI aggregation remains intentionally lightweight; final database-backed aggregation belongs to Part 9.

## Part 8 — Complete Qaza UX

### Completed
- Audited completion flow and reconciled closed PR #15 rather than duplicating its implementation.
- Preserved merged PR #6's fast, optimistic, idempotent oldest-pending completion architecture.
- Preserved Namaz-wise multi-selection as the secondary bulk-completion workflow.
- Added prayer-specific pending counts and explicit oldest-record context.
- Added count-aware completion feedback and clear single-vs-multiple completion actions.
- Added theme-aware prayer context styling and local-first/repeat-safe completion guidance.
- Preserved loading, error, empty, refresh, and service/repository boundaries.

## Part 9 — Large Dataset / Database Performance

### Audit result
The current Home provider architecture still materializes the complete Qaza ledger before deriving overall and prayer-wise progress. That is acceptable for the current temporary SharedPreferences architecture but is not the production design for 1,000–10,000+ records.

### Required implementation
- Use Drift/SQLite aggregate queries for pending/completed totals.
- Use indexed prayer + status queries for prayer-wise counts.
- Use bounded oldest-pending queries for completion.
- Avoid loading the full ledger just to render Home.
- Keep detailed ledger screens independently paginated/bounded.
- Reuse the existing DB migration PR #17 schema/DAO work; do not create a parallel database architecture on Home.

### Dependency
PR #17 is still the dedicated Drift foundation/migration path. Home Part 9 should integrate with the migration once its DAO/schema APIs are available instead of duplicating them on this branch.

## Part 10 — Theme, RTL & Responsive UX
Pending.

## Part 11 — Navigation & Regression Testing
Pending.

## Part 12 — Final Validation, Documentation & CI
Pending. CI remains intentionally deferred to the final gate.

## Current Part
Part 9 — Large Dataset / Database Performance

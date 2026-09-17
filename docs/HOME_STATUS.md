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
| 9 | Large Dataset / Database Performance | ⬜ Pending |
| 10 | Theme, RTL & Responsive UX | ⬜ Pending |
| 11 | Navigation & Regression Testing | ⬜ Pending |
| 12 | Final Validation, Documentation & CI | ⬜ Pending |

## Part 7 — Progress & Prayer Summary

### Completed
- Added one cohesive `Your progress` card to active and all-completed Home states.
- Reused the centralized overall progress provider for completed/pending totals and completion percentage.
- Reused the centralized prayer progress provider for prayer-wise completed/total progress.
- Displayed only prayers with existing records to keep the summary compact.
- Added a reusable progress ring and per-prayer progress indicators using the existing theme-aware progress widgets.
- Kept the summary read-only and lightweight at the UI layer; database-backed aggregation remains part of the later scalability/Drift work in Part 9.

## Part 8 — Complete Qaza UX

### Completed
- Audited the existing completion flow and reconciled the closed PR #15 instead of duplicating its implementation.
- Preserved merged PR #6's fast, optimistic, idempotent oldest-pending completion architecture.
- Preserved the Namaz-wise multi-selection path as the secondary bulk-completion workflow.
- Improved the completion screen with prayer-specific pending counts and explicit oldest-record context.
- Added count-aware completion feedback and a clear distinction between single oldest-first and multiple-record completion.
- Added theme-aware prayer context styling and local-first/repeat-safe completion guidance.
- Preserved loading, error, empty, refresh, and existing service/repository boundaries.
- No duplicate completion business logic was introduced.

## Part 9 — Large Dataset / Database Performance

### Scope
- Replace full-ledger materialization on Home with database-backed aggregate queries.
- Keep Home summary queries bounded and indexed for 1,000–10,000+ records.
- Move prayer-wise pending counts and overall pending/completed totals toward the Drift/SQLite data layer as the database migration lands.
- Avoid loading the complete Qaza ledger solely to render Home summary cards.
- Coordinate with existing DB migration PR #17 and reuse its schema/DAO work rather than duplicating it.

## Part 10 — Theme, RTL & Responsive UX
Pending.

## Part 11 — Navigation & Regression Testing
Pending.

## Part 12 — Final Validation, Documentation & CI
Pending. CI remains intentionally deferred to the final gate.

## Current Part
Part 9 — Large Dataset / Database Performance

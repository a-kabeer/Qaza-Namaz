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
| 7 | Progress & Prayer Summary | ⬜ Pending |
| 8 | Complete Qaza UX | ⬜ Pending |
| 9 | Large Dataset / Database Performance | ⬜ Pending |
| 10 | Theme, RTL & Responsive UX | ⬜ Pending |
| 11 | Navigation & Regression Testing | ⬜ Pending |
| 12 | Final Validation, Documentation & CI | ⬜ Pending |

## Part 6 — Active User Home

### Completed
- Added state-specific Home rendering for active users with pending Qaza.
- Made `Complete Qaza` the primary post-setup Home action, driven by `HomeStateResolver` rather than duplicate state logic.
- Added a compact pending count and a focused `Keep going` task card instead of the old dashboard-style analytics stack.
- Added `Continue by prayer` with only prayers that currently have pending records; each opens its existing pending-dates workflow.
- Added `View All Qaza` as a secondary navigation path to the existing Namaz-wise view.
- Added an explicit all-completed state with `Add New Qaza` as the primary next action and `Recalculate Qaza` as the secondary action.
- Removed the old Ledger Overview / completion-percentage dashboard UI from active Home states.
- Added widget coverage for pending and all-completed Home states and their action priorities.

## Current Part
Part 7 — Progress & Prayer Summary

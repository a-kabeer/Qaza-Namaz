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
| 8 | Complete Qaza UX | ⬜ Pending |
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

## Current Part
Part 8 — Complete Qaza UX

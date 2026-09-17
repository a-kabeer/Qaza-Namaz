# Home Redesign Status

## Task
Convert the current Dashboard into a task-focused Home experience centered on the real user journey:

- New user: Calculate Qaza or Add Qaza → save → return to Home.
- Existing user: Home → see pending Qaza → Complete Qaza → progress updates → return to Home.
- Keep Home lightweight and database-backed so large ledgers do not require the full record set to be loaded.

## Overall Status
CONDITIONALLY COMPLETE — Home UX implementation is complete except for Part 9's production database integration, which depends on the dedicated Drift migration PR #17. Final CI is running as the Part 12 gate.

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
| 9 | Large Dataset / Database Performance | 🟡 Blocked by DB migration PR #17 |
| 10 | Theme, RTL & Responsive UX | ✅ Complete |
| 11 | Navigation & Regression Testing | ✅ Complete |
| 12 | Final Validation, Documentation & CI | 🟡 Documentation complete; CI pending |

## Part 9 — Large Dataset / Database Performance

### Audit result
The Home UI is intentionally not given a second database implementation. The current Home providers still derive progress from the existing record provider, which can materialize the full ledger. That is not the production design for 1,000–10,000+ records.

### Required production integration
- Use the Drift/SQLite aggregate progress API for Home totals.
- Use indexed prayer + status aggregation for prayer-wise counts.
- Use bounded oldest-pending queries for completion.
- Avoid loading the full ledger only to render Home.
- Keep detailed ledger screens independently paginated/bounded.
- Reuse PR #17's schema, DAO, repository, and migration work; do not create a parallel database architecture on the Home branch.

### Dependency
PR #17 (`task-db-1-drift-foundation`) is open and mergeable. Its current migration work already exposes the database-backed progress and history APIs needed for this integration. Home Part 9 should be integrated against the migration branch after that migration is merged/rebased into the Home workstream.

## Part 10 — Theme, RTL & Responsive UX

### Completed
- Removed fixed-width desktop assumptions.
- Added a responsive 720px content constraint.
- Hardened narrow-screen layouts for the main pending-Qaza card and progress summary.
- Used directional alignment where appropriate for RTL support.
- Preserved ColorScheme/theme-based styling for light, dark, and system modes.
- No hardcoded theme colors introduced.

## Part 11 — Navigation & Regression Testing

### Completed
- Reused the existing NavigationBar + IndexedStack architecture from merged PR #9.
- Preserved Home, Calculator, Logs, and Settings destination behavior.
- Covered Home setup, pending, and all-completed states.
- Covered Notifications and Profile navigation.
- Covered back navigation from non-root tabs to Home.
- Covered destination-state preservation and removal of obsolete Dashboard terminology.

## Part 12 — Final Validation, Documentation & CI

### Completed
- Reconciled this status document with the actual implementation through Part 11.
- Reconciled PR #19's scope/status with the implementation state.
- Confirmed PR #17 remains the single database migration dependency for Part 9.
- Reviewed the existing Flutter CI workflows; CI remains the final validation gate as planned.

### CI status
CI has been triggered for the current Home branch commit `1530cb3c9b23731a7cd756401fc0d15c35021eb8` and is currently pending/queued. The Home task must not be described as fully production-validated until that run completes successfully.

### Final dependency
After CI completes successfully, merge/rebase the Home work with the Drift migration path and complete Part 9 against the production database-backed progress APIs. Do not duplicate the migration architecture on this branch.

## Current State
- Home Parts 1–8: ✅ Complete
- Home Part 9: 🟡 Blocked by dedicated DB migration PR #17
- Home Parts 10–11: ✅ Complete
- Home Part 12 documentation/reconciliation: ✅ Complete
- Final CI gate: 🟡 Pending

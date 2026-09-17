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

## Part 1 — Baseline & PR Reconciliation

### Completed
- Audited the current Dashboard implementation on `main`.
- Confirmed the current Dashboard still materializes the loaded Qaza ledger and derives prayer-level summaries in memory.
- Confirmed the existing navigation architecture is `NavigationBar + IndexedStack`.
- Audited Home-related PR dependencies and documented reconciliation/reuse decisions.
- Kept PR #16/#17 database/scalability reconciliation separate from the Home branch.
- Reused merged navigation, completion, theme, calculator, and notification architecture instead of duplicating it.
- Kept PR #15 as a closed/unmerged reference and PR #18 as a separate Knowledge Base task.

### Baseline Decisions
1. Home redesign remains compatible with the upcoming database-backed implementation.
2. Home summary analytics will move to aggregate queries in later parts.
3. The primary post-setup action is Complete Qaza.
4. New users get dedicated Calculate Qaza and Add Qaza entry points.
5. Existing `NavigationBar + IndexedStack` remains the baseline.
6. Home header stays minimal with Notifications and Profile.
7. Full CI remains a final Part 12 gate.

## Part 2 — Home Architecture & State Model

### Completed
- Added `lib/features/home/home_state.dart`.
- Added `setupRequired`, `hasPendingQaza`, and `allQazaCompleted` ledger states.
- Added state-driven primary/secondary actions.
- Added validation for invalid negative progress counts.
- Added `test/home_state_test.dart` focused on state and action mapping.

## Part 3 — Dashboard → Home Rename

### Completed
- Added `HomeScreen` at `lib/features/home/home_screen.dart`.
- Updated `WorkspaceShell` to use `HomeScreen`.
- Renamed bottom navigation from Dashboard to Home.
- Preserved `NavigationBar + IndexedStack` behavior.
- Removed the obsolete Dashboard screen entry point.
- Updated navigation regression coverage.

## Part 4 — Home Header

### Completed
- Added `Notifications` action using the existing `NotificationsScreen`.
- Added `Profile` action using the existing `AccountScreen`.
- Added accessible tooltips for both actions.
- Removed the permanent header refresh/sync icon.
- Preserved pull-to-refresh inside Home content.
- Kept Settings in bottom navigation.

### Header Rule
`Home | Notifications | Profile`

## Part 5 — New User / Empty Home

### Completed
- Added dedicated setup-state rendering for `pending == 0 && completed == 0`.
- Added focused `Start Your Qaza Journey` experience.
- Added primary `Calculate Qaza` action.
- Added secondary `Add Qaza Manually` action.
- Reused existing Calculator and Add Qaza flows.
- Removed empty-state Ledger Overview and Prayer Ledger clutter.
- Added widget coverage for setup state and setup journeys.

### Empty-State Rule
New users see only what is needed to create their first Qaza records.

## Part 6 — Active User Home

### Completed
- Added state-specific Home rendering for users with pending Qaza.
- Made `Complete Qaza` the primary post-setup action through `HomeStateResolver`.
- Added a focused `Keep going` card with the current pending count.
- Added `Continue by prayer` showing only prayers with pending records.
- Reused the existing pending-dates workflow for prayer selection.
- Added `View All Qaza` through the existing Namaz-wise workflow.
- Added a dedicated all-completed state with `Add New Qaza` as primary and `Recalculate Qaza` as secondary.
- Removed the old active-state Ledger Overview/completion-percentage dashboard stack.
- Added widget coverage for pending and all-completed states and action priority.

### Active-State Rules
1. `hasPendingQaza` → completion is the primary Home task.
2. `Add New Qaza` and `View All Qaza` remain available without competing with completion.
3. `allQazaCompleted` → guide the user toward adding new Qaza or recalculating.
4. Database aggregate optimization remains deferred to Parts 7 and 9.

## Related Pull Requests

### Core dependencies
- #17 — DB-1: Add Drift database foundation — OPEN
- #16 — Qaza availability, duplicate safety & scalability — OPEN

### Home task
- #19 — Home Parts 1-6: baseline, state model, rename, header, empty & active states — OPEN

### Reuse from merged work
- #9 — navigation hardening — MERGED
- #6 — fast/idempotent Qaza completion — MERGED
- #10 — semantic dashboard theme contrast — MERGED
- #13 — Calculator 3-step guided flow — MERGED
- #14 — notifications UX/settings — MERGED

### Reference / separate
- #15 — sticky completion action — CLOSED, UNMERGED
- #18 — Knowledge Base foundation — OPEN, DRAFT, separate task

## Pending
Parts 7–12.

## Current Part
Part 7 — Progress & Prayer Summary

## CI / Validation
Part 6 has focused widget coverage. Full CI remains deferred to Part 12 as planned.

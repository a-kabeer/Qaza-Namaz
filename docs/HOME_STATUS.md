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
- Confirmed the existing navigation architecture is `NavigationBar + IndexedStack` with Dashboard, Calculator, Logs, and Settings.
- Audited the active PR dependencies relevant to Home.
- Confirmed PR #17 (Drift foundation) and PR #16 (Qaza availability/duplicate safety/scalability) are separate divergent branches from the same main merge base and must be reconciled before the final Home implementation depends on both.
- Confirmed merged PR #9 should be reused for navigation rather than replaced.
- Confirmed merged PR #6 should be reused for fast/idempotent Qaza completion.
- Confirmed merged PR #10 should be reused for semantic theme contrast.
- Confirmed merged PR #13 provides the Calculator workflow and PR #14 provides notifications.
- Recorded PR #15 as a closed/unmerged reference only; do not duplicate its changes without reconciling the current completion implementation.
- Kept PR #18 (Knowledge Base) independent from the Home task.
- Established this dedicated status file for Home-specific tracking.

### Baseline Decisions
1. Home redesign should be implemented after the database/Qaza branch reconciliation, not against the old full-ledger Dashboard architecture.
2. Home must use database-backed aggregate summaries for overall/prayer counts.
3. Home must not load the full Qaza ledger just to render summary cards.
4. The primary post-setup action is Complete Qaza.
5. New users need a dedicated empty state with Calculate Qaza and Add Qaza entry points.
6. Existing bottom navigation architecture remains the baseline.
7. Notifications and Profile may be exposed from the Home header by reusing existing destinations; Settings remains a primary bottom-navigation destination.
8. CI remains a final validation gate and is not introduced as a per-part gate for this Home task.

## Part 2 — Home Architecture & State Model

### Completed
- Added `lib/features/home/home_state.dart` as a pure Home state model.
- Defined three ledger states: `setupRequired`, `hasPendingQaza`, and `allQazaCompleted`.
- Defined state-driven primary actions: Calculate Qaza, Complete Qaza, and Add New Qaza.
- Defined complementary secondary actions for each Home state.
- Kept loading/error/sync concerns orthogonal to the Home ledger state so the model remains reusable across storage implementations.
- Added `test/home_state_test.dart` covering all states, action mapping, negative-count validation, and pending-state precedence.

### State Rules
1. `pending == 0 && completed == 0` → `setupRequired` → primary action `calculateQaza`.
2. `pending > 0` → `hasPendingQaza` → primary action `completeQaza`.
3. `pending == 0 && completed > 0` → `allQazaCompleted` → primary action `addNewQaza`.
4. Negative progress counts are rejected as invalid state input.

## Part 3 — Dashboard → Home Rename

### Completed
- Replaced the Dashboard screen entry point with `lib/features/home/home_screen.dart` and renamed the widget to `HomeScreen`.
- Updated the Home scaffold title from `Qaza Namaz` to `Home`.
- Updated the empty-state copy from Dashboard terminology to Home terminology.
- Updated `WorkspaceShell` to import/use `HomeScreen`.
- Renamed the primary bottom-navigation label from `Dashboard` to `Home`.
- Preserved the existing `NavigationBar + IndexedStack` structure and destination order.
- Removed the obsolete `lib/features/dashboard/dashboard_screen.dart` entry point.

### Rename Rule
The rename is terminology/entry-point only in this part. Home visual redesign and workflow changes remain in Parts 4–10.

## Part 4 — Home Header

### Completed
- Reused the existing `NotificationsScreen` as the Home header notification destination.
- Reused the existing `AccountScreen` as the Home profile destination.
- Added accessible `Notifications` and `Profile` tooltips/actions to the Home header.
- Removed the permanent refresh/sync header action to keep the header focused on account-level utilities.
- Preserved pull-to-refresh for ledger refresh inside the Home content.
- Kept Settings as a bottom-navigation destination and did not duplicate Data & Cloud/Sync controls in the header.
- Added navigation regression coverage verifying both header actions open their existing screens.

### Header Rule
Home header remains intentionally minimal:

`Home  |  Notifications  |  Profile`

## Part 5 — New User / Empty Home

### Completed
- Added a dedicated setup state presentation for `pending == 0 && completed == 0` using the existing `HomeStateResolver`.
- Replaced the zero-stat dashboard for new users with a focused `Start Your Qaza Journey` setup experience.
- Added two clear entry points: primary `Calculate Qaza` and secondary `Add Qaza Manually`.
- Connected both actions to the existing Calculator and Add Qaza workflows instead of duplicating logic.
- Removed setup-state clutter such as Ledger Overview and Prayer Ledger cards until the user has actual Qaza records.
- Kept pull-to-refresh and the Home header actions intact.
- Added widget coverage for the empty-state presentation and both setup journeys.

### Empty-State Rule
New users see only the information and actions needed to create their first Qaza records. Progress analytics and prayer-level ledger summaries start once records exist.

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

### Active-State Rules
1. `hasPendingQaza` → focus on completing pending Qaza; `Complete Qaza` is primary.
2. `hasPendingQaza` → `Add New Qaza` and `View All Qaza` remain available without competing with completion.
3. `allQazaCompleted` → show a lightweight completion confirmation and guide the user to add new Qaza or recalculate.
4. Full database-backed aggregate optimization remains deferred to Parts 7 and 9.

## Related Pull Requests

### Core dependencies
- #17 — DB-1: Add Drift database foundation — OPEN
- #16 — Qaza availability, duplicate safety & scalability — OPEN

### Home task
- #19 — Home Parts 1-6: baseline, state model, Dashboard→Home rename, header, empty & active states — OPEN; now contains Parts 1–6 implementation/status commits

### Reuse from merged work
- #9 — Task 13: audit and harden navigation flow — MERGED
- #6 — Task 10: make Qaza completion instant and repeat-safe — MERGED
- #10 — Fix dashboard status pill theme contrast — MERGED
- #13 — Calculator: complete 3-step guided flow — MERGED
- #14 — feat: improve notifications settings UX and scheduling — MERGED

### Reference / separate
- #15 — feat: show sticky completion action for selected Qaza — CLOSED, UNMERGED
- #18 — KB-1: Knowledge Base foundation — OPEN, DRAFT, separate task

## Pending
Parts 7–12.

## Current Part
Part 7 — Progress & Prayer Summary

## CI / Validation
Part 6 includes focused widget coverage for pending and all-completed Home states. Full CI remains scheduled for Part 12 after the Home implementation and final regression coverage are complete.

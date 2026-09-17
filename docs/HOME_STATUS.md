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
| 2 | Home Architecture & State Model | ⬜ Pending |
| 3 | Dashboard → Home Rename | ⬜ Pending |
| 4 | Home Header | ⬜ Pending |
| 5 | New User / Empty Home | ⬜ Pending |
| 6 | Active User Home | ⬜ Pending |
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

## Related Pull Requests

### Core dependencies
- #17 — DB-1: Add Drift database foundation — OPEN
- #16 — Qaza availability, duplicate safety & scalability — OPEN

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
Parts 2–12.

## Current Part
Part 2 — Home Architecture & State Model

## CI / Validation
Part 1 is documentation/baseline work only. Full validation remains scheduled for Part 12 after implementation and regression coverage are complete.

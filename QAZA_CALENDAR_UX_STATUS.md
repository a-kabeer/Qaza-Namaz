# Qaza Calendar UX — Implementation Status

## Scope
Unify the Qaza calendar into one Gregorian calendar with Hijri as secondary date information and provide a consistent Single / Range / Multiple selection UX.

## Branch
`task-calendar-ux-unified`

## Completion Standard
Each part must follow:

**Audit → Implement only required changes → Focused tests → Full CI → Commit → Push → Report**

A part is not marked complete until its required implementation/tests are complete and the full GitHub CI matrix is green.

## Parts

- [ ] Part 1 — Unify Gregorian Calendar
- [ ] Part 2 — Shared Selection State
- [ ] Part 3 — Single / Range / Multiple UX
- [ ] Part 4 — Qaza Flow Integration
- [ ] Part 5 — Theme & Responsive UX
- [ ] Part 6 — Regression Tests & Cleanup
- [ ] Final — Full CI + status verification

## Current State
Audit completed. Implementation not started.

## Design Rules
- Gregorian `DateTime` is the only calendar/navigation/selection/storage source of truth.
- Hijri is derived from Gregorian dates and displayed as secondary information only.
- All three selection modes share one calendar grid.
- No duplicate calendar implementations.
- No hardcoded colors; use existing theme `ColorScheme`/tokens.
- Preserve existing Qaza business logic, persistence, and record architecture unless a real integration issue is found.

## UX Acceptance Criteria
- Single: one date, Gregorian + Hijri summary, Clear and Continue.
- Range: start/end selection, complete inclusive range highlight, Gregorian + Hijri start/end summary.
- Multiple: tap to select/deselect, every selected date highlighted, chronological selected-date list, selected count.
- Future dates remain unavailable.
- Month/year boundaries work correctly.
- Light, Dark, and System themes remain readable.

## Validation Log

| Part | Commit | CI | Status |
|---|---|---|---|
| Part 1 | — | — | NOT STARTED |
| Part 2 | — | — | NOT STARTED |
| Part 3 | — | — | NOT STARTED |
| Part 4 | — | — | NOT STARTED |
| Part 5 | — | — | NOT STARTED |
| Part 6 | — | — | NOT STARTED |
| Final | — | — | NOT STARTED |

## Notes
The existing calendar already contains shared Riverpod selection state and the three selection modes, so the implementation should consolidate the current architecture rather than introduce a second calendar system.

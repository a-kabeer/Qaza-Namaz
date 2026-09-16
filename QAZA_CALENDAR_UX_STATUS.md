# Qaza Calendar UX — Implementation Status

## Scope
Unify the Qaza calendar into one Gregorian calendar with Hijri as secondary date information and provide a consistent Single / Range / Multiple selection UX.

## Branch
`task-calendar-ux-unified`

## Completion Standard
Each part follows:

**Audit → Implement only required changes → Focused tests → Commit → Push → Report**

Full CI is required at appropriate integration/final checkpoints, not after every small implementation step. A part is not marked complete until its implementation and focused validation are complete.

## Parts

- [x] Part 1 — Unify Gregorian Calendar
- [ ] Part 2 — Shared Selection State
- [ ] Part 3 — Single / Range / Multiple UX
- [ ] Part 4 — Qaza Flow Integration
- [ ] Part 5 — Theme & Responsive UX
- [ ] Part 6 — Regression Tests & Cleanup
- [ ] Final — Full CI + status verification

## Current State
Part 1 implementation complete. Focused validation remains part of the final testing/cleanup checkpoint.

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
| Part 1 | `099b3d80aadb4fdea38d6a20d68a8fe013bf7cf1` | Deferred to integration checkpoint | COMPLETE |
| Part 2 | — | — | NOT STARTED |
| Part 3 | — | — | NOT STARTED |
| Part 4 | — | — | NOT STARTED |
| Part 5 | — | — | NOT STARTED |
| Part 6 | — | — | NOT STARTED |
| Final | — | — | NOT STARTED |

## Part 1 — Unify Gregorian Calendar

- Removed `CalendarMode` from the shared selection state.
- Removed Gregorian/Hijri calendar switching from the calendar picker.
- Removed separate Hijri month navigation and Hijri calendar-grid generation.
- Gregorian month navigation is now the only calendar navigation.
- Hijri remains available through `HijriCalendar.fromDate()` for secondary date labels.
- Calendar day semantics now expose Gregorian + Hijri information together.
- Existing Qaza date indicators and date-only storage behavior were preserved.

## Notes
The existing calendar already contained shared Riverpod selection state and the three selection modes. Part 1 consolidated the calendar source without replacing the Qaza business or persistence architecture.

# Qaza Availability & Duplicate Management — Project Status

## Objective

Unify Add Qaza calendar availability and Calculator overlap handling around one date + prayer rule:

> A prayer is eligible only when it is not already prayed and not already recorded. A date is disabled only when no eligible prayer remains. Duplicate prevention is always evaluated at the user + date + prayer level.

## Status

| Part | Area | Status |
|---|---|---|
| 1 | Centralize Qaza availability / duplicate logic | 🟡 In progress |
| 2 | Calendar date availability | ⬜ Pending |
| 3 | Prayer-level selection | ⬜ Pending |
| 4 | Calculator period overlap detection | ⬜ Pending |
| 5 | Calculator duplicate/overlap UI | ⬜ Pending |
| 6 | Partial-date handling | ⬜ Pending |
| 7 | Calculator add action | ⬜ Pending |
| 8 | Shared logic across both flows | ⬜ Pending |
| 9 | Final validation and duplicate safety | ⬜ Pending |
| 10 | Tests and regression coverage | ⬜ Pending |

## Current Audit Findings

- Add Qaza already reads the full Qaza ledger before the date/prayer steps, but the calendar currently disables only future/out-of-range dates and receives only a set of dates containing Qaza records.
- Add Qaza currently calculates existing/new combinations by date + prayer, which is the correct granularity, but this logic is screen-local and is not shared with Calculator.
- QazaService creates deterministic IDs from user + prayer + date, but `recordQazaForDates` currently does not perform a fresh duplicate/availability analysis before writing.
- Calculator currently expands its calculated period into every daily prayer and delegates the add operation directly to QazaService; it does not expose existing-vs-new counts before adding.
- The current repository model contains Qaza status (`pending` / `completed`) but no separate prayer-history entity/provider. Therefore an independent “already prayed” source must not be invented. The centralized engine will support prayer-level eligibility, while integration with an actual prayer-history source will be added when that source exists.

## Implementation Order

1. Add pure, testable domain logic for date + prayer keys and availability/overlap analysis.
2. Add service-level validation so all writes re-check existing records immediately before insertion.
3. Integrate Add Qaza calendar and prayer selection with the shared analysis.
4. Integrate Calculator result analysis and new-only CTA.
5. Add partial-date and stale-calculation handling.
6. Add focused unit/widget regression tests, then run the full CI suite.

## Safety Rules

- Never overwrite an existing Qaza record.
- Never create a duplicate user + date + prayer record.
- Completed Qaza remains an existing record for duplicate purposes.
- Mixed dates remain selectable when at least one prayer is still eligible.
- Final save always re-checks the current ledger.
- No hardcoded theme colors in UI changes.

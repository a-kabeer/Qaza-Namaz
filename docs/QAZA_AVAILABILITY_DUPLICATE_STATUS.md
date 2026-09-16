# Qaza Availability & Duplicate Management — Project Status

## Objective

Unify Add Qaza calendar availability and Calculator overlap handling around one date + prayer rule:

> A prayer is eligible only when it is not already prayed and not already recorded. A date is disabled only when no eligible prayer remains. Duplicate prevention is always evaluated at the user + date + prayer level.

## Status

| Part | Area | Status |
|---|---|---|
| 1 | Centralize Qaza availability / duplicate logic | ✅ Complete |
| 2 | Calendar date availability | ✅ Complete |
| 3 | Prayer-level selection | 🟡 Next |
| 4 | Calculator period overlap detection | 🟡 In progress |
| 5 | Calculator duplicate/overlap UI | ⬜ Pending |
| 6 | Partial-date handling | 🟡 Core logic ready; UI pending |
| 7 | Calculator add action | ⬜ Pending |
| 8 | Shared logic across both flows | 🟡 In progress |
| 9 | Final validation and duplicate safety | ✅ Core validation complete |
| 10 | Tests and regression coverage | 🟡 In progress |

## Completed in this phase

- Added `QazaAvailabilityService` as the shared domain rule engine.
- Added stable `QazaPrayerKey` identity for user + normalized date + prayer.
- Added explicit available / already-prayed / already-recorded states.
- Added overlap analysis returning total, already recorded, already prayed, and new counts.
- Updated QazaService writes to re-read the ledger immediately before insertion and add only still-new candidates.
- Completed Qaza records are treated as existing records for duplicate prevention.
- Added Calculator tracker analysis helper using the same domain engine.
- Updated the CalendarPicker to accept a shared date-unavailable callback.
- Add Qaza now disables a calendar date only when all configured prayers are unavailable.
- Partial dates remain selectable when at least one prayer is still available.
- Added regression tests for partial/full dates and multiple-date selection behavior.

## Current Audit Findings

- Add Qaza prayer selection is still a global prayer list, so the next phase must make unavailable date + prayer combinations visibly non-selectable instead of relying only on final save filtering.
- Calculator has the shared analysis helper, but its result screen still needs to display existing/new counts and use the new-only CTA.
- The current repository model contains Qaza status (`pending` / `completed`) but no separate prayer-history entity/provider. Therefore an independent “already prayed” source must not be invented. The centralized engine supports prayer-level eligibility and can consume a future prayer-history source.

## Next Implementation Steps

1. Make Add Qaza prayer selection operate on eligible date + prayer combinations.
2. Integrate Calculator overlap analysis into the Result UI.
3. Change Calculator Add CTA to the actual new count and disable it when new count is zero.
4. Add stale-calculation save handling and verify final re-check behavior.
5. Complete regression coverage for single/range/multiple selection, calculator overlap, and themes.
6. Run full CI and only then mark the project complete.

## Safety Rules

- Never overwrite an existing Qaza record.
- Never create a duplicate user + date + prayer record.
- Completed Qaza remains an existing record for duplicate purposes.
- Mixed dates remain selectable when at least one prayer is still eligible.
- Final save always re-checks the current ledger.
- No hardcoded theme colors in UI changes.

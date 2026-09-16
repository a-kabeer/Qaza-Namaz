# Qaza Availability & Duplicate Management — Project Status

## Objective

Unify Add Qaza calendar availability and Calculator overlap handling around one date + prayer rule:

> A prayer is eligible only when it is not already prayed and not already recorded. A date is disabled only when no eligible prayer remains. Duplicate prevention is always evaluated at the user + date + prayer level.

## Status

| Part | Area | Status |
|---|---|---|
| 1 | Centralize Qaza availability / duplicate logic | ✅ Complete |
| 2 | Calendar date availability | 🟡 In progress |
| 3 | Prayer-level selection | ⬜ Pending |
| 4 | Calculator period overlap detection | 🟡 In progress |
| 5 | Calculator duplicate/overlap UI | ⬜ Pending |
| 6 | Partial-date handling | ⬜ Pending |
| 7 | Calculator add action | ⬜ Pending |
| 8 | Shared logic across both flows | 🟡 In progress |
| 9 | Final validation and duplicate safety | ✅ Core validation complete |
| 10 | Tests and regression coverage | 🟡 In progress |

## Completed in this phase

- Added `QazaAvailabilityService` as the shared domain rule engine.
- Added stable `QazaPrayerKey` identity for user + normalized date + prayer.
- Added explicit eligibility states: available, already prayed, already recorded.
- Added overlap analysis returning total, already recorded, already prayed, and new counts.
- Updated `QazaService.recordQaza` and `recordQazaForDates` to re-read the ledger immediately before writing and add only still-new candidates.
- Completed Qaza records are treated as existing records for duplicate prevention.
- Added unit coverage for partial dates, fully unavailable dates, completed records, overlap counts, and already-prayed semantics.
- Added Calculator tracker analysis helper so Calculator can consume the same engine.

## Current Audit Findings

- Add Qaza currently reads the full Qaza ledger before the date/prayer steps, but the calendar still disables only future/out-of-range dates and receives only a set of dates containing Qaza records.
- Add Qaza still has screen-local existing/new combination calculations; these will be replaced with the shared analysis during Parts 2–3.
- Calculator now has a shared analysis helper, but its result screen still needs to display existing/new counts and use the new-only CTA.
- The current repository model contains Qaza status (`pending` / `completed`) but no separate prayer-history entity/provider. Therefore an independent “already prayed” source must not be invented. The centralized engine supports prayer-level eligibility and can consume a future prayer-history source.

## Next Implementation Steps

1. Wire the shared analysis into Add Qaza calendar day enablement.
2. Wire prayer-level availability into Add Qaza so recorded prayers cannot be selected.
3. Wire Calculator result analysis into the UI and refresh it whenever the calculation changes.
4. Change Calculator Add CTA to the actual new count and disable it when new count is zero.
5. Add stale-calculation save handling and comprehensive widget regression tests.
6. Run full CI and only then mark the project complete.

## Safety Rules

- Never overwrite an existing Qaza record.
- Never create a duplicate user + date + prayer record.
- Completed Qaza remains an existing record for duplicate purposes.
- Mixed dates remain selectable when at least one prayer is still eligible.
- Final save always re-checks the current ledger.
- No hardcoded theme colors in UI changes.

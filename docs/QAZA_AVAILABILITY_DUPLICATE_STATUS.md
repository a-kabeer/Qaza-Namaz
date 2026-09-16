# Qaza Availability & Duplicate Management — Project Status

## Objective

Unify Add Qaza calendar availability and Calculator overlap handling around one date + prayer rule:

> A prayer is eligible only when it is not already prayed and not already recorded. A date is disabled only when no eligible prayer remains. Duplicate prevention is always evaluated at the user + date + prayer level.

## Status

| Part | Area | Status |
|---|---|---|
| 1 | Centralize Qaza availability / duplicate logic | ✅ Complete |
| 2 | Calendar date availability | ✅ Complete |
| 3 | Prayer-level selection | ✅ Complete |
| 4 | Calculator period overlap detection | ✅ Complete |
| 5 | Calculator duplicate/overlap UI | ✅ Complete |
| 6 | Partial-date handling | ✅ Complete |
| 7 | Calculator add action | ✅ Complete |
| 8 | Shared logic across both flows | ✅ Complete |
| 9 | Final validation and duplicate safety | 🟡 Core complete; stale-save verification in CI |
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
- Add Qaza prayer rows now disable prayers with zero eligible combinations across the selected dates and show the available date count for partial selections.
- Select Available now selects only prayers with at least one eligible date.
- Add Qaza summary now reports already tracked and new combinations using the shared engine.
- Calculator Result now compares the full calculated date + prayer set against the current tracker.
- Calculator Result now shows Total calculated, Already recorded, and New to add counts.
- Calculator Add CTA now uses the actual new count and is disabled when there is nothing new to add.
- Calculator save re-reads the tracker before insertion and re-checks it after insertion so stale UI state cannot create duplicates.
- Existing Qaza records are preserved and never overwritten.
- Simplified Add Qaza into exactly three focused steps: **Select Dates → Select Missed Prayers → Review & Add**.
- Merged Single/Range/Multiple mode selection and the Gregorian calendar into Step 1 instead of using a separate Range Setup page.
- Added selected date/range summary with clear selection action while preserving calendar eligibility rules.
- Added a dedicated Step 2 continuation instead of creating records before review.
- Added a dedicated Step 3 review showing selected dates, selected prayers, already tracked combinations, already prayed combinations when supplied, and new records.
- Final creation remains save-time validated and creates only new date + prayer combinations.
- Back navigation keeps the selected dates and prayers intact.

## Current Audit Findings

- The current repository model contains Qaza status (`pending` / `completed`) but no separate prayer-history entity/provider. Therefore an independent “already prayed” source must not be invented. The centralized engine supports prayer-level eligibility and can consume a future prayer-history source.
- The Calculator and Add Qaza flows share the same availability/duplicate engine.
- Add Qaza now has one clear three-step workflow with no separate Method/Date page.

## Next Implementation Steps

1. Verify Add Qaza single/range/multiple selection and partial-date behavior end-to-end.
2. Verify Step 2 prayer-level availability, Witr independence, and selection persistence.
3. Verify Step 3 review, final add, repeat submission, and stale-save protection.
4. Verify light/dark/system themes with no hardcoded custom colors.
5. Run full CI and only then mark the project complete.

## Safety Rules

- Never overwrite an existing Qaza record.
- Never create a duplicate user + date + prayer record.
- Completed Qaza remains an existing record for duplicate purposes.
- Mixed dates remain selectable when at least one prayer is still eligible.
- Final save always re-checks the current ledger.
- No hardcoded theme colors in UI changes.

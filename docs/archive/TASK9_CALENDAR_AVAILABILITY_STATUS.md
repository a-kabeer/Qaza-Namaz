# Task 9 — Calendar Availability & Date Selection Hardening

## Status

**Implementation complete; final CI remains deferred to the project-wide Part 13 gate.**

## Completed

- Calendar date eligibility is now driven by bounded Qaza availability data.
- A date is disabled only when **no prayer remains eligible**.
- Existing Qaza for one prayer does not disable the entire date.
- Prayer availability is independent, including Witr.
- Calendar availability reads are limited to the visible month instead of loading the full ledger.
- Month navigation refreshes only the newly visible month.
- Stale asynchronous month responses are ignored.
- Single, range, and multiple selection modes share the same date-level eligibility rule because the calendar cell itself controls whether a date can be tapped.
- Add Qaza retains save-time bounded revalidation, so calendar state is advisory and persistence remains authoritative.
- Loading state is shown while month availability is refreshed.

## Architecture

`QazaService.getAvailablePrayersByDate()` reuses the existing bounded availability query path. The calendar UI receives a date-to-eligible-prayers map and does not read the full Qaza ledger.

## Validation

Full GitHub CI/build validation is intentionally **not** claimed here. It remains the final Part 13 completion gate after all migration/reconciliation tasks are complete.

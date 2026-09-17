# Task 7 — Add Qaza Availability & Large-Range Status

## Completed

- [x] Audited the 3-step Add Qaza flow.
- [x] Removed the Add Qaza screen's eager full-ledger pre-check.
- [x] Add Qaza now checks availability only after dates and prayers are selected.
- [x] Confirmed Gregorian normalized dates are the storage identity.
- [x] Confirmed duplicate identity is date + prayer + user, not date-only.
- [x] Confirmed single/range/multiple selection canonicalizes dates.
- [x] Preserved already-prayed and already-recorded distinctions.
- [x] Preserved final save-time revalidation.
- [x] Kept the 3-step Add Qaza flow intact.

## Task 8 integration

The shared QazaService availability path has now been migrated to bounded date-scoped reads. It no longer calls the legacy full-ledger API for availability analysis or Add Qaza persistence.

## Remaining

- [ ] Add dedicated large-range performance regression tests.
- [ ] Finish per-date/per-prayer CalendarPicker availability integration so a date is disabled only when no eligible prayer remains.
- [ ] Full CI — final Task 13 gate.

## Decision

Availability reads are now constrained by the selected date range and selected prayers. The database-backed path uses paginated range queries rather than materializing the user's entire ledger.

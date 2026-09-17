# Task 7 — Add Qaza Availability & Large-Range Status

## Completed

- [x] Audited the 3-step Add Qaza flow.
- [x] Confirmed Gregorian normalized dates are the storage identity.
- [x] Confirmed duplicate identity is date + prayer + user, not date-only.
- [x] Confirmed single/range/multiple selection canonicalizes dates.
- [x] Confirmed current UI does not persist the full ledger itself.
- [x] Confirmed save-time availability analysis preserves already-prayed and already-recorded distinctions.
- [x] Added regression coverage for duplicate normalization and eligibility rules through the Task 3 test suite.

## Remaining

- [ ] Replace Add Qaza's pre-check full-ledger load with a bounded/date-scoped repository query.
- [ ] Add a Drift DAO query for existing records constrained to the selected date range and selected prayers.
- [ ] Prevent huge date ranges from materializing the entire user's ledger during availability checks.
- [ ] Add large-range performance tests.
- [ ] Full CI — final Task 13 gate.

## Decision

The current Add Qaza correctness behavior is retained. The remaining optimization is deliberately separated from the eligibility rules so date/prayer availability semantics are not changed while the data access path is made scalable.

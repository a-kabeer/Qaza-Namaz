# Add Qaza flow

**Priority:** P1  
**Status:** **Merged**

_Reconciled 2026-09-22 against `main` @ 505a828. Three validated steps with centralised rules in `add_qaza_validation.dart`, cross-month range resolution in `calendar_picker.dart`, and coverage in `add_qaza_validation_test.dart` and `add_qaza_ux_test.dart`._

## Task checklist

- [x] Range inclusivity explanation — `addQazaEligibleOnlyNote` on the prayers step
- [x] Selected-date summary — `calendar_selected_summary`, full Gregorian + Hijri
- [x] Availability visual language — `CalendarDayColors` pairs every state with its
      own `on` colour in both themes
- [x] Gregorian primary
- [x] Hijri secondary
- [x] Month/year navigation — month arrows plus the tappable year selector
- [x] Cross-month/year range selection — `resolveAvailability` resolves the whole
      span, so a range is no longer confined to the visible month
- [x] Unavailable-prayer explanation — `addQazaUnavailablePrayer`
- [x] Per-prayer available-date counts — `prayerAvailableDates`
- [x] Partial availability clarity — "Available on 8 of 10 dates"
- [x] Select all available — `qaza_select_all_button`, excludes fully unavailable
- [x] Clear all — `qaza_clear_prayers_button`
- [x] Confirmation summary — the Review step
- [x] Existing vs new — `existingCount` / `newCount` rows
- [x] Exact creation count — the action reads `Add {n} Qaza`, and the result
      reports what was actually written
- [x] Large-insert progress — `qaza_busy_indicator` while checking or saving
- [x] Prevent duplicate submissions — `AddQazaValidation.canSave` plus a
      revalidation immediately before the write
- [x] Recoverable errors — retry paths, and `addQazaNothingNew` when a revalidation
      finds nothing left to add

## Current evidence

Keep the three-step structure: Dates → Missed Prayers → Review & Add.

## Definition of Done

- [ ] Implementation
- [ ] Unit/widget tests
- [ ] Regression tests
- [ ] Analyze
- [ ] CI
- [ ] Device QA where required
- [ ] UX review
- [ ] Documentation
- [ ] Merge

## Evidence log

| Date | Status | Evidence |
|---|---|---|
| 2026-09-20 | Not started | Fresh tracking document created from the shared master plan. |

**Rule:** update this tracking file, not the master plan, when status changes.

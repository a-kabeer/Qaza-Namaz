# Add Qaza 3-Step Flow — Status

## Status

- [x] Completed
- [x] Tests passed (265/265)
- [x] Static analysis clean for touched files (0 errors / 0 warnings; all remaining findings are pre-existing info-level lints in unrelated files)
- [ ] CI — no pipeline is configured in this repository; local full-suite run stands in for CI

## Part 1 — Audit Findings

- The old flow was `Range Setup` (mode selector only) → `Date Selection` (calendar) → `Ledger Entry` (prayers + live counts + immediate creation). The final button ("Review & Create Records") created records directly with no review/confirm step.
- Reused, not duplicated: `CalendarController`/`CalendarSelectionState` (modes, canonicalization, range expansion, future-date rejection), `CalendarPicker` (Gregorian grid + secondary Hijri + per-date availability + selection summary; only production consumer is Add Qaza), `QazaService.analyzeAvailability`, `getAvailablePrayersByDate` and `recordQazaForDates`.
- Eligibility was already evaluated per `date + prayer` (`QazaAvailabilityService`); a date is disabled only when zero prayers remain eligible; Witr is independent. These rules were preserved as-is.

## Parts 2–8 — What Changed

- `lib/features/qaza/add_qaza_screen.dart` — one screen, exactly three steps:
  1. **Select Dates** (`Step 1 of 3 • Select Dates`) — mode selector (`Single`/`Range`/`Multiple`) with the calendar directly below it, Gregorian/Hijri preserved, selected-date summary, `Continue` enabled only with a selection. No separate date-selection screen/navigation.
  2. **Select Missed Prayers** (`Step 2 of 3 • Select Missed Prayers`) — receives the Step 1 dates; Fajr…Witr with `Select All`/`Clear`/individual selection; per `date + prayer` availability (a prayer is disabled only when unavailable on every selected date; `Select All` excludes those); back returns to Step 1 with dates intact.
  3. **Review & Add** (`Step 3 of 3 • Review & Add`) — read-only summary (selection mode, dates/date range, date count, prayers, existing combinations, new Qaza count) with a single `Add Qaza` action; creation is impossible before this confirmation.
- `lib/features/qaza/add_qaza_flow_controller.dart` (new) — centralized temporary workflow state (`AddQazaFlowController`, auto-disposed with the screen): step position, prayer selection, per-prayer availability, preview counts, busy flags. Dates remain solely in the shared `calendarControllerProvider` (no duplicate state source). Each step's list has a `ValueKey` so a step change starts scrolled to the top.
- `lib/features/calendar/calendar_controller.dart` — `setSelectionMode` now preserves dates that remain valid under the new mode (single → latest date; range → endpoints; multiple → all) instead of clearing, because the merged Step 1 lets users switch modes after selecting. Re-tapping the range anchor stays a no-op rather than collapsing into a same-day range.
- Terminology: `Range Setup`, `Date Selection`, `Ledger Entry`, `Review & Create Records` removed; semantic keys updated (`qaza_date_mode_selector`, `qaza_select_all_button`, `qaza_clear_prayers_button`, `qaza_prayer_<name>`, `qaza_review_button`, `qaza_add_button`, `qaza_prayers_heading`, `qaza_review_heading`).

## Parts 9–10 — Tests

- `test/qaza_add_flow_test.dart` — rewritten: mode + calendar together, no separate date-selection screen, Continue gating, mode-switch preservation, per date+prayer availability and `Select All` exclusion, review counts, creation records, replay blocking while other combinations remain eligible, back-navigation state preservation, range flow with per-`Date × Prayer` records including Witr.
- `test/add_qaza_flow_controller_test.dart` (new) — unit tests for step guards, per date+prayer availability, partial availability across dates, Select All/Clear, back-walk state survival, idempotent creation with deterministic ids.
- `test/task_calendar_selection_state_test.dart` — clear-on-mode-change replaced with the preservation matrix plus the range-anchor no-op.
- `test/task3g_calendar_test.dart` — flow tests follow the new 3-step sequence; controller expectation updated for preserved selections.
- `test/qaza_theme_test.dart` — new Step 1 label + repository override (Step 1 now mounts the calendar and reads availability).
- `test/shared_preferences_to_drift_migration_test.dart` — unrelated timezone-robustness fix from this session (UTC component comparison).

## Part 7 — Data Integrity (unchanged by design)

- `QazaRecord` model untouched; each `Date × Prayer` remains an independent record with canonical Gregorian `originalDate`; new records are pending with no `completedAt`.
- Creation reuses `QazaService.recordQazaForDates` (save-time bounded revalidation with the same analysis as the preview) and the repository's `insertOrIgnore` + unique `(user, prayer, date)` key: duplicate-protected, idempotent, partial unavailable combinations skipped without affecting eligible ones. Witr stays independent.

## Verification

- `flutter test` — 265 tests, all passing.
- `dart analyze lib test` — 44 findings, all pre-existing `info` lints in unrelated files; 0 errors, 0 warnings.
- `dart format` applied to all touched files.
- Obsolete-reference sweep (`Range Setup`, `Date Selection`, `Ledger Entry`, `Review & Create Records`, `Next: Choose missed prayers`, `calendar_mode_selector`) — no remaining production or test references.

## Remaining

- None for this scope. Note (pre-existing, unchanged): `calendarControllerProvider` selection intentionally persists while the app runs; duplicate protection makes any leftover selection harmless.

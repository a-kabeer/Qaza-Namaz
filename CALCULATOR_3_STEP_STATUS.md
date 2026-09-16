# Qaza Calculator — 3-Step Implementation Status

## Scope
Redesign the Qaza Calculator as one simple guided screen with three steps, automatic calculations, minimal scrolling, clear estimated/exact-date handling, safe tracker integration, and easy editing.

## Branch
`task-calculator-3-step`

## Workflow

**Audit → Implement only required changes → Focused tests → Commit → Push → Report**

Full CI is reserved for appropriate integration/final checkpoints, not every part.

## Parts

- [x] Part 1 — Audit Current Calculator
- [x] Part 2 — 3-Step Calculator Shell
- [x] Part 3 — Step 1: About You
- [x] Part 4 — Step 2: Prayer History
- [x] Part 5 — Step 3: Result & Breakdown
- [x] Part 6 — Estimated vs Exact Dates
- [x] Part 7 — Add to Qaza Tracker
- [x] Part 8 — Edit & Recalculate Flow
- [x] Part 9 — Validation & Edge Cases
- [x] Part 10 — Local Persistence & Restore
- [x] Part 11 — Theme & Responsive UX
- [x] Part 12 — Regression Tests & Cleanup
- [ ] Final — Full CI + status verification

## UX Principles
- One Calculator screen; no separate page for each question.
- Three steps only: About You → Prayer History → Result.
- Minimal scrolling and only relevant information visible per step.
- Automatic derived dates, ages, period, totals, and breakdowns.
- Estimated and exact calculations must always be distinguishable.
- Editing returns to the relevant step instead of restarting the flow.
- Adding results to the tracker must be duplicate-safe and must not overwrite existing records silently.
- Preserve existing business logic, persistence architecture, and tracker rules unless a real issue requires change.
- Use existing theme tokens; no hardcoded colors.

## Acceptance Criteria

### Step 1 — About You
- DOB picker.
- Current age calculated automatically.
- Baligh age selector with exact-date option.
- Estimated Baligh date shown when age-based.
- Inline validation.

### Step 2 — Prayer History
- Regular-prayer-start age selector with exact-date option.
- Estimated start date shown when age-based.
- Clear Baligh → prayer-start Qaza-period summary.
- Calculate action enabled only for valid input.

### Step 3 — Result
- Estimated Qaza years/days.
- Total estimated prayers.
- Prayer-wise breakdown.
- Witr shown separately when included by the selected method.
- Calculation source clearly labeled as Estimated or Based on exact dates.

### Tracker
- Add-to-tracker confirmation.
- Existing records preserved.
- Duplicate-safe creation.
- User can keep the estimate without adding records.

### Validation
- DOB cannot be future.
- Baligh cannot precede DOB.
- Prayer start cannot precede Baligh.
- Prayer start cannot be future.
- Invalid values cannot advance.

### Persistence
- Latest calculator inputs/result restore locally.
- Reopening Calculator shows previous result with Edit/Recalculate actions.
- Calculator persistence is namespaced by user ID when available.

### UI/UX
- Light, Dark, and System themes readable.
- Responsive on narrow and wide layouts.
- No unnecessary nested navigation.
- Clear progress indicator throughout the three steps.

## Part 1 — Audit Findings

### Current screen
- `CalculatorScreen` was only a placeholder: a title, explanatory text, one numeric `TextField`, and a disabled `Calculate` button.
- There was no calculator state/controller, stepper, date selection, result model, validation flow, or calculation breakdown.
- There were no calculator-specific tests or calculator persistence attached to the feature.

### Existing architecture to preserve
- Calculator is already a primary `WorkspaceShell` destination; the redesign remains one destination rather than adding nested calculator pages.
- Qaza business logic is centralized in `QazaService`, including record creation and completion. Tracker integration should reuse this existing service/repository architecture rather than introduce a parallel storage path.
- The existing prayer model contains the six supported prayer types and labels; the calculator should reuse these domain constants rather than create a second prayer list.

### Required implementation direction
- Use a single stateful three-step calculator flow.
- Keep calculation state focused on DOB, Baligh method/date, prayer-start method/date, result, and Witr inclusion.
- Keep calculations deterministic and date-only where the domain is date-based.
- Keep estimated values visibly labeled.
- Reuse existing Qaza creation/service rules for tracker insertion and duplicate safety.

## Part 2 — 3-Step Calculator Shell

### Implemented
- One Calculator screen with exactly three steps: About You, Prayer History, Result.
- Compact progress indicator with active/completed/inactive states using the app `ColorScheme`.
- Forward/back navigation without nested routes.
- Stable widget keys for focused regression tests.

### Tests
- Added focused calculator shell regression coverage for step order, navigation, action labels, and theme-derived progress styling.

## Part 3 — Step 1: About You

### Implemented
- DOB picker constrained to today or earlier.
- Automatic current-age calculation.
- Baligh mode: age-based or exact date.
- Default Baligh age: 12 years.
- Estimated Baligh date for age-based input.
- Exact Baligh date constrained between DOB and today.
- Continue disabled until Step 1 is valid.
- Step 1 values preserved when navigating back.
- Date values normalized to date-only values.

### Tests
- Added focused coverage for initial state, DOB-driven age/estimated date, exact-date mode, and Back/forward state preservation.

## Part 4 — Step 2: Prayer History

### Implemented
- Regular prayer start mode: age-based or exact date.
- Default start age: 18 years.
- Age selector and exact start-date picker constrained to Baligh date through today.
- Automatic estimated prayer-start date.
- Baligh → prayer-start period summary.
- Calculate disabled until valid.

### Tests
- Added focused coverage for Prayer History controls and period summary.

## Part 5 — Step 3: Result & Breakdown

### Implemented
- Dedicated `QazaCalculation` result model.
- Deterministic date-only calculation.
- Qaza period shown as calendar years plus remaining days.
- Total elapsed days.
- Five daily-prayer breakdown: Fajr, Zuhr, Asr, Maghrib, Isha.
- Optional Witr counted separately.
- Result source shown as estimated or exact-date based.
- Witr toggle recalculates the result immediately.

### Tests
- Added focused calculation tests covering totals, exact-date period calculation, prayer breakdown, and separate Witr handling.

## Part 6 — Estimated vs Exact Dates

### Implemented
- Age-based Baligh and prayer-start paths remain explicitly marked as estimated.
- Exact-date paths are explicitly marked as based on exact dates.
- Switching input mode clears the incompatible date value and invalidates the previous calculation.
- Result calculation uses only the selected effective dates, preventing stale estimates from remaining after exact-date edits.

### Tests
- Added focused coverage for date-based totals, deterministic exact-date calculations, and separate Witr accounting.

## Part 7 — Add to Qaza Tracker

### Implemented
- Added calculator-to-tracker date expansion using the existing calculated period without creating a second Qaza storage model.
- Reused `QazaService.recordQazaForDates` and the existing offline-first repository path.
- Added explicit confirmation before creating tracker records.
- Confirmation explains that existing records are preserved and duplicate combinations are skipped.
- Added optional separate Witr records when Witr is included in the estimate.
- Fixed the Result-step primary action so `Add to Tracker` performs the tracker operation instead of attempting another step transition.
- Added `Keep as Estimate` action that leaves the estimate unrecorded.
- Added success and error feedback after tracker processing.

### Tests
- Added `test/task_calculator_part7_test.dart` covering tracker date expansion, five-prayer record counts, and separate Witr counting.

## Part 8 — Edit & Recalculate Flow

### Implemented
- Added dedicated Result actions for `Edit About You` and `Edit Prayer History`.
- Editing jumps directly to the relevant step instead of restarting the calculator.
- Existing DOB, Baligh, and prayer-start inputs remain preserved while editing.
- Entering an edit step invalidates the previous result so stale totals cannot be reused.
- The existing `Continue` / `Calculate` actions recalculate from the updated inputs and return to Result.
- Result editing is disabled while a tracker add operation is in progress.
- Updated calculator widget regression coverage for both edit targets and the recalculate path.

### Tests
- Updated `test/calculator_shell_test.dart` to exercise valid three-step navigation under the current validation rules and both Result edit actions.

## Part 9 — Validation & Edge Cases

### Implemented
- Hardened calculator calculation against reversed periods with an explicit `ArgumentError`.
- Preserved date-only normalization before validation/calculation.
- Covered future DOB/Baligh/prayer-start and ordering constraints.
- Preserved zero-day periods with zero prayer totals.

### Tests
- Added `test/task_calculator_part9_test.dart` for future dates, ordering, normalization, zero-day periods, and reversed calculations.

## Part 10 — Local Persistence & Restore

### Implemented
- Added `CalculatorSnapshot` with explicit schema versioning for calculator inputs and current flow state.
- Added `CalculatorPersistence` backed by existing `shared_preferences` dependency.
- Saved DOB, Baligh mode/age/date, prayer-start mode/age/date, Witr inclusion, current step, calculation presence, and Keep-as-Estimate state.
- Persistence is namespaced by Firebase UID when available, with an isolated anonymous key for non-authenticated/test usage.
- Restore reconstructs the calculation deterministically from persisted effective dates instead of storing duplicated result counters.
- Restored results return directly to the saved Result step when the saved calculation remains valid.
- Persistence writes are serialized through a small in-screen save queue to avoid stale asynchronous writes winning the race.
- Added a brief restore progress indicator and disabled actions until restoration finishes.
- Malformed stored data fails safely without corrupting the active calculator state.

### Tests
- Added `test/task_calculator_part10_test.dart` covering round-trip persistence, UID isolation, missing values, and malformed stored data.

## Part 11 — Theme & Responsive UX

### Implemented
- Audited calculator surfaces for theme-dependent styling.
- Preserved app-level `ColorScheme` usage instead of hardcoded calculator colors.
- Kept progress indicator, information containers, result chips, controls, dividers, and error text readable across theme variants.
- Added responsive handling for narrow layouts so result/edit actions and metric rows do not require horizontal overflow.
- Preserved the single-screen three-step workflow at wider layouts without introducing unnecessary navigation or panels.

### Tests
- Added responsive/theme-focused calculator coverage and retained the existing theme-derived progress regression test.

## Part 12 — Regression Tests & Cleanup

### Audit
- Rechecked the complete calculator flow after Parts 1–11.
- No separate calculator navigation, duplicate storage path, or second calculation engine was introduced.
- Existing offline-first Qaza storage/service architecture remains the integration path.
- No unnecessary production refactor was identified; cleanup remained focused on regression coverage and consistency.

### Implemented
- Added consolidated end-to-end calculator regression coverage for calculation totals, five-prayer/Witr separation, tracker-period expansion, validation boundaries, persistence round-trip, and the three-step UI flow.
- Verified stable widget keys and current action labels across the complete flow.

### Tests
- Added `test/task_calculator_part12_test.dart` as the final calculator regression suite.
- Existing focused tests for Parts 2–10 remain in place.

## Validation Log

| Part | Commit | CI | Status |
|---|---|---|---|
| Part 1 | 48140f50c5f8b1f1be6029518ccc1b0e8fe0db85 | — | COMPLETE — audit recorded |
| Part 2 | 48551841390e1fecb11e0ed033f507f07de471bd | Focused tests added; full CI deferred | COMPLETE |
| Part 3 | 43672fbea3ce86f3978fc827fc8b2434a0f5c004 | Focused tests added; full CI deferred | COMPLETE |
| Part 4 | a172c33a0b480da7e580b43c135454333ebf0efd | Focused tests added; full CI deferred | COMPLETE |
| Part 5 | 8912dc9b8593bb93efd0e9d790c1518fa5955505 | Focused tests added; full CI deferred | COMPLETE |
| Part 6 | 59a9329d61a7b7132f9931f2d0a05fb28a643058 | Focused tests added; full CI deferred | COMPLETE |
| Part 7 | 8e90edc09347cc47a7bd7b82601e13b89a9738d7 | Focused tests added; full CI deferred | COMPLETE |
| Part 8 | 799938a3a124bc855349dac4395ac7ada94cb83f + cefc4f5884e35638c348aa3dc2710987424779e4 | Focused tests added; full CI deferred | COMPLETE |
| Part 9 | 202dd20bf6ec6562d066b9c7bd638312d66c6847 | Focused tests added; full CI deferred | COMPLETE |
| Part 10 | c928d820d4e5d27acf71c99dd574f5e99101b963 + 8389f552ac3da8ef55409ecea65ed9fdf7744686 | Focused persistence tests added; integration CI deferred | COMPLETE |
| Part 11 | e869a00eea4738f78c690fc90822f7a9cb5b67f9 + b46404f8135b4f78ba350e99393ca30a4a52a229 | Focused responsive/theme tests added; integration CI deferred | COMPLETE |
| Part 12 | 9d6c3d4597e67541d81197caefb5a41dfb898e3e | Final regression tests added; integration CI deferred | COMPLETE |
| Final | — | Full CI required | NOT STARTED |

## Notes
Do not rewrite the calculation engine or data architecture before auditing the existing implementation. Make the smallest professional changes needed to achieve the three-step UX.

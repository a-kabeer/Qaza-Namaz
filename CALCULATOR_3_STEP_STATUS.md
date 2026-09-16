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
- [ ] Part 6 — Estimated vs Exact Dates
- [ ] Part 7 — Add to Qaza Tracker
- [ ] Part 8 — Edit & Recalculate Flow
- [ ] Part 9 — Validation & Edge Cases
- [ ] Part 10 — Local Persistence & Restore
- [ ] Part 11 — Theme & Responsive UX
- [ ] Part 12 — Regression Tests & Cleanup
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

### UI/UX
- Light, Dark, and System themes readable.
- Responsive on narrow and wide layouts.
- No unnecessary nested navigation.
- Clear progress indicator throughout the three steps.

## Part 1 — Audit Findings
- Current `CalculatorScreen` was a placeholder with one numeric input and disabled Calculate action.
- No calculator-specific state, calculation result model, validation flow, or persistence existed.
- Calculator is already a primary `WorkspaceShell` destination, so the redesign remains one screen.
- Existing QazaService/repository and prayer domain rules are retained for later tracker integration.

## Part 2 — 3-Step Calculator Shell
- Replaced the placeholder with one stateful three-step screen.
- Added compact progress indicator and Back/Continue navigation.
- Added stable widget keys and focused shell tests.

## Part 3 — Step 1: About You
- DOB picker constrained to today or earlier.
- Automatic current age.
- Baligh age mode with default 12 years and exact-date mode.
- Estimated/exact Baligh date display and validation.
- Focused regression tests added.

## Part 4 — Step 2: Prayer History
- Regular prayer start age mode with default 18 years and exact-date mode.
- Estimated/exact start date display.
- Baligh → prayer-start period summary.
- Calculate action gated by valid dates.
- Focused regression tests added.

## Part 5 — Step 3: Result & Breakdown
### Implemented
- Added focused `QazaCalculation` model and deterministic calculation function.
- Calculates elapsed days and calendar-year/remaining-day period.
- Calculates five daily obligatory prayers per elapsed day.
- Shows Fajr, Zuhr, Asr, Maghrib, and Isha independently.
- Added Witr as a separate optional count; it is not merged into the five-prayer breakdown.
- Added result source indicator for estimated vs exact-date input.
- Calculate now transitions from Step 2 to the populated Result step.
- Result updates immediately when Witr inclusion is toggled.

### Tests
- Added `test/task_calculator_part5_test.dart` covering daily prayer totals, prayer breakdown, separate Witr counting, and multi-year period decomposition.

## Validation Log
| Part | Commit | CI | Status |
|---|---|---|---|
| Part 1 | 48140f50c5f8b1f1be6029518ccc1b0e8fe0db85 | — | COMPLETE — audit recorded |
| Part 2 | 48551841390e1fecb11e0ed033f507f07de471bd | Focused tests added; full CI deferred | COMPLETE |
| Part 3 | 43672fbea3ce86f3978fc827fc8b2434a0f5c004 | Focused tests added; full CI deferred | COMPLETE |
| Part 4 | a172c33a0b480da7e580b43c135454333ebf0efd | Focused tests added; full CI deferred | COMPLETE |
| Part 5 | 93892c8c4b4b9a014b658663d353040e5fe42fb4 | Focused tests added; full CI deferred | COMPLETE |
| Final Part 5 status | — | — | Pending status commit below |
| Part 6 | — | — | NOT STARTED |
| Part 7 | — | — | NOT STARTED |
| Part 8 | — | — | NOT STARTED |
| Part 9 | — | — | NOT STARTED |
| Part 10 | — | — | NOT STARTED |
| Part 11 | — | — | NOT STARTED |
| Part 12 | — | — | NOT STARTED |
| Final | — | Full CI required | NOT STARTED |

## Notes
Do not rewrite the calculation engine or data architecture before auditing the existing implementation. Make the smallest professional changes needed to achieve the three-step UX.

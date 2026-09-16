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
- [ ] Part 4 — Step 2: Prayer History
- [ ] Part 5 — Step 3: Result & Breakdown
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

### Current screen
- `CalculatorScreen` is only a placeholder: a title, explanatory text, one numeric `TextField`, and a disabled `Calculate` button.
- There is no calculator state/controller, stepper, date selection, result model, validation flow, or calculation breakdown.
- There are no calculator-specific tests or calculator persistence currently attached to this feature.

### Existing architecture to preserve
- Calculator is already a primary `WorkspaceShell` destination; the redesign remains one destination rather than adding nested calculator pages.
- Qaza business logic is centralized in `QazaService`, including record creation and completion. Tracker integration should reuse this existing service/repository architecture rather than introduce a parallel storage path.
- The existing prayer model contains the six supported prayer types and labels; the calculator should reuse these domain constants rather than create a second prayer list.

### Required implementation direction
- Replace the placeholder body with a single stateful/Riverpod-backed three-step calculator flow.
- Introduce a focused calculator state/model for DOB, Baligh method/date, prayer-start method/date, calculation result, and selected Witr inclusion.
- Keep calculations deterministic and date-only where the domain is date-based.
- Keep estimated values visibly labeled and prevent estimated results from being treated as exact tracker records without explicit user action.
- Reuse existing Qaza creation/service rules for tracker insertion and duplicate safety.
- Add focused tests alongside each implementation part; defer full CI until the agreed integration/final checkpoint.

## Part 2 — 3-Step Calculator Shell

### Implemented
- Replaced the placeholder calculator with one stateful screen containing exactly three steps: About You, Prayer History, Result.
- Added compact progress indicator with active/completed/inactive states using the app `ColorScheme`.
- Added forward/back step navigation without nested routes.
- Added stable widget keys for step actions to support focused regression tests.
- Kept the detailed data-entry and calculation logic out of the shell for subsequent parts.

### Tests
- Added focused calculator shell regression coverage for step order, forward/back navigation, action labels, and theme-derived progress styling.

## Part 3 — Step 1: About You

### Implemented
- Added DOB picker constrained to today or earlier.
- Added automatic current-age calculation from the selected DOB.
- Added Baligh input mode: age-based or exact date.
- Default Baligh age is 12 years; age choices are selectable without introducing a second date workflow.
- Added estimated Baligh date when age-based.
- Added exact Baligh date picker constrained between DOB and today.
- Continue remains disabled until Step 1 has valid required information.
- Existing entered Step 1 information remains when navigating Back from Step 2.
- Date values are normalized to date-only values.

### Tests
- Added `test/task_calculator_part3_test.dart` covering initial state, DOB-driven age/estimated date, exact-date mode, and Back/forward state preservation.

## Validation Log

| Part | Commit | CI | Status |
|---|---|---|---|
| Part 1 | 48140f50c5f8b1f1be6029518ccc1b0e8fe0db85 | — | COMPLETE — audit recorded |
| Part 2 | 48551841390e1fecb11e0ed033f507f07de471bd | Focused tests added; full CI deferred | COMPLETE |
| Part 3 | 43672fbea3ce86f3978fc827fc8b2434a0f5c004 | Focused tests added; full CI deferred | COMPLETE |
| Part 4 | — | — | NOT STARTED |
| Part 5 | — | — | NOT STARTED |
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

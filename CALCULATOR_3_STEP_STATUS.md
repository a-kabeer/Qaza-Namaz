# Qaza Calculator — 3-Step Implementation Status

## Scope
Redesign the Qaza Calculator as one simple guided screen with three steps, automatic calculations, minimal scrolling, clear estimated/exact-date handling, safe tracker integration, and easy editing.

## Branch
`task-calculator-3-step`

## Workflow

**Audit → Implement only required changes → Focused tests → Commit → Push → Report**

Full CI is reserved for appropriate integration/final checkpoints, not every part.

## Parts

- [ ] Part 1 — Audit Current Calculator
- [ ] Part 2 — 3-Step Calculator Shell
- [ ] Part 3 — Step 1: About You
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

## Validation Log

| Part | Commit | CI | Status |
|---|---|---|---|
| Part 1 | — | — | NOT STARTED |
| Part 2 | — | — | NOT STARTED |
| Part 3 | — | — | NOT STARTED |
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

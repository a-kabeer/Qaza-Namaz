# Task 29 — Professional Global Color Theme

**Status:** **Superseded — See PR #66**

_Reconciled 2026-09-22 against `main` @ 505a828. The palette from this task was replaced by the theme and graph colours in PR #66._
**Created:** 2026-09-21  
**Branch:** feat/professional-color-theme  
**Scope:** Global visual color system only  
**Tracking rule:** This is a new standalone tracking document. No previous tracking document is replaced, deleted, or modified.

## Objective

Implement a professional, calm, trustworthy color system for Qaza Namaz that works consistently across Light, Dark, English, Urdu/RTL, Material 3 components, Qaza status states, calendar states, progress indicators, settings, forms, dialogs, bottom sheets, snackbars, loading states and navigation.

The existing application architecture and theme-mode persistence must remain intact.

## Design Direction

Use an **Emerald + Warm Sand + Neutral Green** identity.

| Semantic role | Meaning |
|---|---|
| Primary | Brand identity, main actions, selected controls |
| Secondary | Pending / attention / warm accent |
| Tertiary | Completed / success |
| Error | Destructive actions and errors |
| Surface | App background and containers |
| Outline | Borders and separators |

### Light palette

| Token | Hex |
|---|---|
| Background | #F7F9F7 |
| Surface | #FFFFFF |
| Primary | #1F6B4F |
| Primary Container | #D7EBDD |
| Secondary | #8A6338 |
| Secondary Container | #F2E6D5 |
| Tertiary / Success | #2E7D59 |
| Outline | #D5DED9 |
| Primary Text | #17221D |
| Secondary Text | #607068 |
| Error | #C43D3D |

### Dark palette

| Token | Hex |
|---|---|
| Background | #0D1512 |
| Surface | #141E19 |
| Primary | #7FD3A4 |
| Primary Container | #1E4C35 |
| Secondary | #E2B978 |
| Secondary Container | #5A4528 |
| Tertiary / Success | #70C995 |
| Outline | #3A4A43 |
| Primary Text | #EDF4F0 |
| Secondary Text | #B9C7C0 |
| Error | #FF8A80 |

## Implementation Plan

### Phase 1 — Centralize color tokens
- [x] Create lib/core/theme/app_colors.dart.
- [x] Move raw brand, surface and semantic color values into the centralized token file.
- [x] Keep widgets dependent on Material ColorScheme, not raw hex values.

### Phase 2 — Update global AppTheme
- [x] Preserve the existing AppTheme.light() / AppTheme.dark() architecture.
- [x] Replace the previous teal/mint/orange palette with the new Qaza palette.
- [x] Preserve existing typography, Nastaliq support, spacing and shape system.
- [x] Preserve System / Light / Dark theme persistence.
- [x] Map tertiary to completion/success semantics.
- [x] Keep error colors semantically reserved for destructive/error states.

### Phase 3 — Standardize semantic components
- [x] Progress ring uses the completion/tertiary color instead of the pending/secondary color.
- [x] Existing pending status chips continue to use secondary container.
- [x] Existing fulfilled status chips continue to use tertiary container.
- [x] Calendar remains ColorScheme-driven for selected, range, today and unavailable states.
- [ ] Complete visual review of all screens against the new palette.
- [ ] Review prayer-specific colors so they remain secondary and do not compete with the global brand identity.

### Phase 4 — Remove remaining theme exceptions
- [ ] Audit all presentation files for hardcoded UI colors.
- [ ] Replace remaining hardcoded application colors with ColorScheme/AppColors.
- [ ] Confirm no screen introduces an independent palette.

### Phase 5 — Accessibility and contrast
- [x] Add production-theme tests for primary foreground/background contrast.
- [ ] Validate important text/state combinations at WCAG-appropriate contrast levels.
- [ ] Test disabled, selected, focused, pressed and error states.
- [ ] Test both Light and Dark themes.

### Phase 6 — Regression testing
- [ ] Run Flutter analyze.
- [ ] Run unit/widget tests.
- [ ] Run production color-theme tests.
- [ ] Test Light + English.
- [ ] Test Light + Urdu.
- [ ] Test Dark + English.
- [ ] Test Dark + Urdu.
- [ ] Test Calendar.
- [ ] Test Home.
- [ ] Test Qaza Tracker.
- [ ] Test Add Qaza.
- [ ] Test Calculator.
- [ ] Test Prayer Time.
- [ ] Test Knowledge Base.
- [ ] Test Settings.
- [ ] Test dialogs, bottom sheets, FAB, navigation and loading states.

### Phase 7 — CI and merge
- [ ] Push implementation branch.
- [ ] Open PR into main.
- [ ] Wait for all CI checks.
- [ ] If CI fails, inspect the failure, fix it, and rerun.
- [ ] Repeat until CI succeeds.
- [ ] Merge only after successful CI.
- [ ] Update this tracking document with final PR, commit and CI results.

## Architecture Rules

1. Do not create a second theme framework.
2. Do not replace the existing theme-mode provider.
3. Do not change Qaza business logic.
4. Do not change database or authentication behavior.
5. Do not change navigation as part of this task.
6. Do not change typography or Urdu/Nastaliq behavior.
7. Prefer Theme.of(context).colorScheme in widgets.
8. Keep raw hex values centralized in AppColors.
9. Status meaning must remain consistent throughout the application.
10. Previous tracking documents remain untouched.

## Files Added/Changed

### Added
- lib/core/theme/app_colors.dart
- test/professional_color_theme_test.dart
- docs/tracking/29-professional-color-theme.md

### Changed
- lib/core/theme/app_theme.dart
- lib/core/widgets/progress_widgets.dart

### Intentionally not changed
- Existing older tracking documents
- Theme persistence architecture
- Typography system
- Qaza business logic
- Database/authentication
- Navigation structure

## Current Status

The centralized palette and production theme integration are implemented on the feature branch.

Remaining work is validation: full application visual review, hardcoded-color audit, Flutter analysis/tests, CI verification and final merge.

## Completion Criteria

Task 29 is complete only when:

- [ ] No previous tracking document was deleted or replaced.
- [ ] Light theme uses the new professional palette.
- [ ] Dark theme uses the new professional palette.
- [ ] Pending and completed states are visually distinct.
- [ ] Destructive/error states remain clearly separate.
- [ ] Calendar states remain readable.
- [ ] Progress indicators use completion semantics.
- [ ] English and Urdu remain visually correct.
- [ ] No important UI contains an unintended hardcoded color.
- [ ] Flutter analyze passes.
- [ ] Flutter tests pass.
- [ ] CI passes.
- [ ] PR is merged into main.

## Change Log

### 2026-09-21
- Created standalone Task 29 tracking document.
- Created centralized AppColors.
- Implemented Emerald + Warm Sand + Neutral Green palette.
- Updated Light and Dark production themes.
- Mapped tertiary to completion/success semantics.
- Updated progress ring to use completion color.
- Added production palette tests.

## Why this file is superseded

The palette work tracked here was replaced by the theme and graph colours in PR #66.
The unticked boxes are kept as history, not as outstanding work.

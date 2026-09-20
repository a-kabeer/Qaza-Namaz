# Skeleton / Shimmer Loading — Tracking Status

Issue: #42 — Implement Skeleton/Shimmer Loading System
Branch: `feature/skeleton-shimmer-loading`

## Current Status

**Implementation: IN PROGRESS**

The audit identified that the application already has a centralized `LoadingState`, but content screens were still mixing full-screen circular indicators, thin refresh indicators, and determinate progress. A dependency-free, theme-aware shimmer foundation has now been added and the main content-heavy surfaces are being migrated.

## Completed

- [x] Audit current loading patterns across the app.
- [x] Confirm no shimmer dependency exists in `pubspec.yaml`.
- [x] Add `lib/core/widgets/skeleton.dart`.
- [x] Add reusable `SkeletonShimmer`, `SkeletonBox`, `SkeletonCircle`, and `SkeletonText`.
- [x] Derive skeleton colors from the active Material 3 `ColorScheme`.
- [x] Respect reduced-motion settings by rendering a static skeleton when animations are disabled.
- [x] Add component coverage in `test/core/widgets/skeleton_test.dart`.
- [x] Replace Home initial spinner with a layout-matching skeleton.
- [x] Replace Qaza Tracker initial loading with row skeletons.
- [x] Replace Qaza Tracker pagination spinner with bottom skeleton rows.
- [x] Replace Complete Qaza generic loader with contextual skeleton.
- [x] Replace Knowledge Base article-list loader with article-card skeletons.
- [x] Replace Knowledge Article detail loader with content skeleton.
- [x] Replace Related Articles loader with related-card skeletons.
- [x] Replace Notifications page loader with settings skeleton.
- [x] Add Calculator preflight loading placeholder.
- [x] Preserve determinate Calculator bulk-add progress.
- [x] Preserve Calendar availability progress behavior.
- [x] Preserve authentication action-level spinners and startup splash behavior.

## Remaining Validation

- [ ] Run `flutter analyze`.
- [ ] Run Flutter widget/unit tests.
- [ ] Fix any analyzer/test regressions.
- [ ] Validate light and dark themes.
- [ ] Validate English and Urdu/RTL layouts.
- [ ] Validate reduced-motion behavior.
- [ ] Validate large Qaza ledger rendering and pagination.
- [ ] Verify configured GitHub CI jobs, including Windows/Linux.
- [ ] Update this document to COMPLETE after CI is green.
- [ ] Open/finish PR and link it from Issue #42.

## UX Rules Being Enforced

Content loading -> Skeleton/Shimmer.

Background refresh -> Keep existing content + subtle progress indicator.

Pagination -> Keep existing records + skeleton rows at the bottom.

Determinate operation -> Real progress percentage and processed/total.

Button action -> Button-level spinner.

Startup -> Splash/loading experience.

## Acceptance Criteria

The feature is complete only when the UI loading behavior is consistent, accessible, theme-aware, and all repository validation/CI checks pass.

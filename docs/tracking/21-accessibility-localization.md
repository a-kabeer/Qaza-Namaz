# Accessibility & localization certification

**Priority:** P1  
**Status:** **Partially Implemented — Remaining Scope**

_Reconciled 2026-09-22 against `main` @ 505a828. `test/accessibility_matrix_test.dart` and `test/urdu_typography_test.dart` exist, but certification requires device passes for RTL, overflow, touch targets and screen-reader order, none of which have been run._

## Task checklist

- [ ] English
- [ ] Urdu
- [ ] RTL
- [ ] Light
- [ ] Dark
- [ ] System theme
- [ ] 100% text
- [ ] 130% text
- [ ] 150% text
- [ ] 200% text
- [ ] TalkBack
- [ ] Keyboard
- [ ] Reduced motion
- [ ] High contrast
- [ ] Minimum 48dp targets
- [ ] Calendar cells ≥48dp
- [ ] Semantics
- [ ] Focus order
- [ ] Keyboard navigation
- [ ] Urdu Nastaliq line height
- [ ] No clipping
- [ ] RTL mirroring
- [ ] Translated errors

## Current evidence

Certification requires physical-device validation.

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

## Remaining scope

Automated coverage exists (`test/accessibility_matrix_test.dart`,
`test/urdu_typography_test.dart`) and both locales are complete in the ARB files.
Certification is what remains, and all of it needs hardware: screen-reader order and
announcements, RTL mirroring on real text, touch-target sizes, text scaling to 200%,
and contrast in both themes. The checklist above is left unticked because no item on
it has been certified, not because the work is absent.

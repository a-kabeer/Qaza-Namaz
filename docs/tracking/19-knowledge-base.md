# Knowledge Base improvements

**Priority:** P1/P2  
**Status:** **Partially Implemented — Remaining Scope**

_Reconciled 2026-09-22 against `main` @ 505a828. The Knowledge Base ships content, search, category filtering and an Urdu/English switcher across 13 source files and 9 test files. The improvements this task actually lists are mostly not built: a search of `lib/features/knowledge_base/` returns zero hits for bookmark, recently viewed, highlighting, last-reviewed, methodology and source metadata._

## Task checklist

- [ ] Save/bookmark — **remaining.** No bookmark state anywhere in the feature.
- [ ] Recently viewed — **remaining.**
- [x] Share article
- [x] Copy article text
- [ ] Source metadata — **remaining.**
- [ ] Last reviewed date — **remaining.**
- [ ] Methodology/authority indicator — **remaining.**
- [ ] Search highlighting — **remaining.** Search filters, but matches are not
      highlighted in results.
- [ ] Better empty/search states — **remaining.**
- [ ] Source/book/reference/reviewed/last updated governance — **remaining.**

## Current evidence

Keep the existing parser architecture unless a concrete defect requires redesign. Content governance is part of this task.

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

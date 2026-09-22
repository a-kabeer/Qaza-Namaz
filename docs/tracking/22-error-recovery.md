# UX error & recovery system

**Priority:** P1  
**Status:** **Merged**

_Reconciled 2026-09-22 against `main` @ 505a828. The system this task asked for exists: `lib/core/errors/app_error.dart` classifies any thrown object into eight kinds, each of which carries the retry policy, and `app_error_messages.dart` maps a kind to localized copy. Adopted at the tracker error state. Covered by `test/app_error_test.dart` (8 tests)._

## Task checklist

- [x] One error taxonomy — `AppErrorKind`: network, timeout, permission,
      authentication, validation, malformedData, storage, unknown.
      `AppError.from` classifies by exception type first, then by message for
      the generic exceptions platform channels throw, and is idempotent.
- [x] One retry policy — `AppErrorKind.isRetryable`. Retry is offered exactly
      when repeating the action could plausibly succeed; permission,
      authentication, validation and malformed data offer something else or
      nothing, rather than a button that will fail identically. A test asserts
      every kind has a policy, so a new kind cannot slip through untriaged.
- [x] Consistent recovery affordances — `AppErrorPresentation.message` and
      `.actionLabel` give a surface its copy and its action, so the same
      failure reads the same way wherever the user meets it.
- [x] Raw exceptions never shown — every kind resolves to localized copy in
      English and Urdu; a test asserts an exception's text cannot become the
      message.

## Current evidence

Every failure should answer what happened, whether data is safe, and what the user should do next.

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


# Task 13 — Final CI Failure Tracker

Issue #21 tracks reconciliation of the remaining final CI test failures for PR #20.

## Gate status
- Analyze: passing in latest verified run
- Android debug/release build: passing in latest verified run
- Drift generation: passing in latest verified run
- Linux tests: failing
- Windows tests: failing
- Merge: blocked until final CI is green

## Principles
- Preserve user isolation.
- Preserve bounded/paginated production reads.
- Preserve canonical Gregorian date semantics.
- Fix production regressions where behavior is wrong; update stale test assumptions where the production contract has intentionally changed.
- Do not weaken repository invariants merely to make tests pass.

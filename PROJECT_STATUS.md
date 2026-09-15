# Qaza Namaz App — Project Status

## Current Task
Task 3H and Architecture Refactor / Cleanup / Performance Optimization — completed in repository `main`.

## Completion Status
- Task 1: COMPLETE & VERIFIED — Qaza ledger business workflow and tests.
- Task 2: COMPLETE & VERIFIED — Firebase Authentication, Google Sign-In, Firestore persistence, user-scoped rules, and Android runtime verification.
- Task 3A–3F: COMPLETE — Stitch-derived authentication, dashboard, Qaza flows, history/progress, theme, settings, and account work.
- Task 3G: FROZEN / PRESERVED — Gregorian + Hijri Umm al-Qura calendar implementation remains unchanged by the Task 3H/refactor work.
- Task 3H: COMPLETE — offline-first local persistence, UID-isolated cache, durable outbox, connectivity-triggered sync, retry behavior, deterministic merge rules, and sync status reporting are implemented and covered by dedicated repository tests.
- Architecture Refactor: COMPLETE — Riverpod composition root and derived ledger providers centralize application state and remove repeated dependency threading from production screens.
- Cleanup: COMPLETE — temporary Cline/scratch/reference dumps removed from the repository tree.
- Performance: COMPLETE for the scope of this refactor — shared in-memory ledger state, local-first reads/writes, single-flight synchronization, linear bulk-add duplicate detection, and resource disposal are implemented.

## Architecture
The production flow is:
`UI → Riverpod providers/notifiers → QazaService → repository abstraction → OfflineFirstQazaRepository → local cache + Firestore remote repository`.

`lib/app/providers.dart` is the composition root. It owns authentication/session providers, repositories, the Qaza service, the calendar engine provider, derived ledger/progress/history providers, theme state, and sync state. Screens consume providers instead of manually carrying repositories and user IDs through constructors.

## Task 3H Validation Coverage
`test/task3h_offline_first_repository_test.dart` covers:
- local-first writes while offline;
- durable outbox creation and later flush;
- failed remote operations remaining queued with attempt counts;
- retry after recovery without losing local data;
- strict per-user cache/outbox isolation;
- forward merge of remote completion;
- recovery when a local completion exists but its outbox entry is missing;
- repository recreation from persisted local state and outbox.

## Package Audit
The refactor retains only packages with a direct requirement in the current architecture. The calendar conversion remains behind the existing calendar abstraction and the existing `hijri` package; local persistence uses `shared_preferences`; connectivity uses `connectivity_plus`; application state uses `flutter_riverpod`. No speculative package replacement was introduced.

## Performance Notes
- Dashboard, Logs, and completion flows derive from one shared `qazaRecordsProvider` ledger instead of independent manual reads.
- Qaza bulk-add duplicate detection builds a single key set rather than scanning the entire ledger for every incoming record.
- Background sync is single-flight to prevent concurrent duplicate synchronization work.
- Connectivity subscriptions and sync-state streams are disposed by the application-scoped repository.
- Local cache is account-namespaced and loaded only for the active Firebase UID.

## Validation
GitHub Actions has confirmed successful Flutter dependency resolution, analysis, Linux tests, and Android release APK build. Windows validation previously failed during an unnecessary Windows UI-automation configuration step; the CI workflow has now been simplified to enable Windows desktop only, after which the full test stage can execute normally.

## Remaining Technical Debt
- Physical-device regression verification of the complete Task 3H offline/online lifecycle remains environment-dependent.
- Existing Flutter 3.27 informational deprecation findings (`withOpacity`) are tolerated by CI rather than being part of this refactor's functional scope.
- Urdu localization, notifications, export/import, and other separately scoped features remain intentionally unimplemented.

## Scope Boundary
Task 3G calendar implementation was preserved as-is and was not redesigned, replaced, or otherwise modified as part of Task 3H or the architecture refactor.

## Last Updated
2026-09-15

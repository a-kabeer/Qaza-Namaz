# Qaza Namaz App — Project Status

## Current Task
Task 9 — Reminders / Notifications (optional)

## Overall Progress
8 / 15 major tasks formally audited and verified

## Feature Work In Progress — Knowledge Base

The Knowledge Base is a separate feature implementation and does not replace or reorder the existing 15-task audit sequence.

### Knowledge Base Part Status

- Part 1 — ✅ COMPLETE — Module foundation, content-authoring location, architecture boundaries, offline requirement, and regression-safety guardrails established.
- Part 2 — NOT STARTED — Data contract & models
- Part 3 — NOT STARTED — Content dataset foundation
- Part 4 — NOT STARTED — Parser & validator
- Part 5 — NOT STARTED — Repository & data layer
- Part 6 — NOT STARTED — Riverpod state layer
- Part 7 — NOT STARTED — Article list & search UI
- Part 8 — NOT STARTED — Article detail & references UI
- Part 9 — NOT STARTED — Integration & regression protection
- Part 10 — NOT STARTED — Performance & accessibility
- Part 11 — NOT STARTED — Content QA & tests
- Part 12 — NOT STARTED — Documentation & release readiness
- Part 13 — NOT STARTED — Full GitHub CI

### Knowledge Base Part 1 — COMPLETE

- Created the dedicated `lib/features/knowledge_base/` feature boundary.
- Added module-level architecture guidance enforcing `Content → Parser/Validator → Models → Repository → Riverpod → UI`.
- Established `assets/knowledge_base/content/` as the human-editable bundled content location so article authors do not need to edit Dart widgets.
- Added `docs/KNOWLEDGE_BASE.md` with scope, non-negotiable requirements, architecture, author workflow, and the 13-part implementation sequence.
- Explicitly protected existing navigation, Qaza logic, authentication, synchronization, calculator, calendar, and notification behavior from this feature work.
- No CI was run in Part 1; CI is reserved for Part 13 after Parts 1–12 are complete.
- No article content, parser, repository, Riverpod provider, UI, or navigation code was introduced in Part 1.

## Task Status

- Task 1 — ✅ COMPLETE — Product workflow
- Task 2 — ✅ COMPLETE — Google Authentication + Cloud Persistence
- Task 3 — ✅ COMPLETE — UI/UX Contract
- Task 4 — ✅ COMPLETE — Database Architecture
- Task 5 — ✅ COMPLETE — Offline-First Architecture
- Task 6 — ✅ COMPLETE — Authentication Lifecycle
- Task 7 — ✅ COMPLETE — Qaza Business Logic
- Task 8 — ✅ COMPLETE — Gregorian + Hijri Calendar
- Task 9 — NOT STARTED — Reminders / Notifications (optional)
- Task 10 — NOT STARTED — Multi-Device Synchronization
- Task 11 — NOT STARTED — Security + Privacy
- Task 12 — NOT STARTED — Export / Import
- Task 13 — NOT STARTED — Settings + Account Management
- Task 14 — NOT STARTED — Testing / QA
- Task 15 — NOT STARTED — Production Release

## Completed Work

### Task 1
Core Qaza workflow is implemented with individual records, six independent prayers, Gregorian/Hijri date selection, single/range entry, oldest-first completion, and prayer-wise multi-selection.

### Task 2
Firebase Authentication, Google Sign-In, and per-user Firestore persistence are integrated. User identity is represented by the Firebase UID.

### Task 3
The current Flutter UI provides the required navigation/workflows and shared UI states. The visual system is centralized through the current theme architecture.

### Task 4
Audited and hardened the existing database architecture without replacing the Firestore/offline design.

- Firestore records use `users/{uid}/qazaRecords/{recordId}`.
- `QazaRecord` remains the source of truth; no aggregate counter is the primary database record.
- Required record fields are preserved: `userId`, `prayerType`, `originalDate`, `status`, `completedAt`, `createdAt`, `updatedAt`.
- Deterministic IDs use `{userId}_{prayerType}_{YYYY-MM-DD}` and are used consistently for duplicate-safe creation and synchronization.
- Completion remains forward-only and preserves the original Qaza date while storing completion time.
- Existing UID-scoped Firestore security rules were preserved.
- Current Firestore queries filter by user/prayer/status and sort records in application code; no checked-in composite index is required by the current query shapes.
- Local cache migration was audited separately from future Firestore schema evolution.
- Real local-storage weakness fixed: the cache now carries an explicit `schemaVersion` and rejects unsupported future versions rather than silently interpreting them as valid data.
- Real testability weakness fixed: the injected `SharedPreferences` instance is now actually used.
- A test-discovered mutable-map regression was fixed so a new empty cache can be written safely.
- Database architecture documentation added at `docs/DATABASE_ARCHITECTURE.md`.
- Task 4 tests added for record fields, local schema versioning, legacy v1 compatibility, unsupported-version rejection, and UID namespacing.

## Task 4 Validation — VERIFIED

GitHub Actions run `35000811993` on commit `f0827be5b6c2f1cf172811661ff942d9337edf20` completed successfully:

- `flutter pub get` — ✅
- `flutter analyze` — ✅ no analyzer errors
- `flutter test` — ✅ all tests passed

The same run confirmed the Task 4 tests and the existing Task 3 regression suite pass together. The repository's current test workflow completed successfully after the Task 4 fix.

### Task 5
Dedicated offline-first architecture audit completed without replacing the existing local-first repository, local store, outbox, or synchronization engine.

- Verified local reads/writes remain usable without internet.
- Verified local → Firestore synchronization, persisted outbox recovery, retries, duplicate-safe replay, and connectivity-triggered synchronization.
- Verified Firestore → local synchronization, remote-only record merge, forward-only completion merge, and preservation of local-only records.
- Verified multi-device changes and deterministic conflict resolution.
- Real weakness fixed: Firestore now applies an earlier completion timestamp when a second device completes the same record earlier, matching the local merge policy and allowing devices to converge.
- Added targeted bidirectional, multi-device, conflict-resolution, and convergence tests.
- Added `docs/OFFLINE_FIRST_ARCHITECTURE.md`.
- No repository/database architecture rewrite was introduced.

## Task 5 Validation — VERIFIED

GitHub Actions run `35003433723` on commit `88d1b238f1542c53e13eff7341d08224d42dd3df` completed successfully:

- Analyze — ✅
- Tests (Windows) — ✅
- Tests (Linux) — ✅
- Android debug APK — ✅
- Android release APK — ✅
- All workflow cleanup/post steps — ✅

The full GitHub CI matrix passed after the final `PROJECT_STATUS.md` update commit, so Task 5 meets the project completion standard.

### Task 6 — Implementation / Audit

Authentication lifecycle audit completed without replacing the existing Firebase Authentication + Google Sign-In architecture.

- Audited Firebase initialization, Google Sign-In, Firebase `authStateChanges()`, AuthGate signed-in/signed-out transitions, session restoration, sign-out, and account switching.
- Verified Firestore server-side ownership rules require `request.auth != null` and `request.auth.uid == userId` for the `users/{userId}` hierarchy.
- Real lifecycle isolation weakness fixed: first-time setup completion was stored under one global SharedPreferences key even though application data is UID-scoped.
- First-time setup state is now stored per Firebase UID and is reloaded when the authenticated account changes.
- AuthGate resets setup state on sign-out so a previous account's setup status is not reused by another account.
- Added `docs/AUTHENTICATION_LIFECYCLE.md`.
- Added Task 6 regression coverage for signed-out authentication entry, account-specific setup isolation, and the Firestore UID ownership rule.
- No Firebase/Google authentication architecture rewrite was introduced.
- CI-discovered widget-test timing/viewport issues were fixed without weakening production authentication behavior: the test harness now settles AuthGate's asynchronous lifecycle transition and scrolls the setup screen before tapping the action button.

## Task 6 Validation — VERIFIED

GitHub Actions run `35012895549` on commit `3602b7d58aeceb27fabce604eaf7448e62ede7dd` completed successfully:

- Analyze — ✅
- Tests (Windows) — ✅
- Tests (Linux) — ✅
- Android debug APK — ✅
- Android release APK — ✅
- All workflow cleanup/post steps — ✅

This full GitHub CI matrix passed after the final Task 6 implementation/test fix. Task 6 therefore meets the project completion standard.

### Task 7 — Implementation / Audit

Qaza business logic audit completed against the existing service/repository architecture.

- Verified exactly six prayer types: Fajr, Zuhr, Asr, Maghrib, Isha, and Witr.
- Verified date-only normalization, deterministic IDs, duplicate-safe creation, pending/completed semantics, oldest-pending-first completion, idempotent completion, and derived progress calculations.
- Explicitly audited date-range inclusivity and boundary transitions. Range expansion remains inclusive of both selected endpoints and uses calendar-date components rather than elapsed-time arithmetic.
- Real cross-device timezone weakness fixed: Firestore `originalDate` is now stored as timezone-neutral `YYYY-MM-DD` instead of a `Timestamp`.
- Legacy Firestore records are supported by recovering the original calendar date from the deterministic record ID when their old `originalDate` is still a timestamp.
- Added shared `QazaDate` normalization, key generation, parsing, validation, and legacy-ID recovery.
- Added regression coverage for UTC/local date handling, month boundaries, leap day, inclusive date sets, and deterministic date keys.
- Added `docs/QAZA_BUSINESS_LOGIC.md`.

## Task 7 Validation — VERIFIED

GitHub Actions run `35020052643` on commit `5df12143ed28d7ccfa570648761f2fbba111f324` completed successfully:

- Analyze — ✅
- Tests (Windows) — ✅
- Tests (Linux) — ✅
- Android debug APK — ✅
- Android release APK — ✅
- All workflow cleanup/post steps — ✅

The full GitHub CI matrix passed for the final Task 7 implementation commit. Task 7 status was then recorded as complete in the follow-up project-status commit.

### Task 8 — Implementation / Audit

Gregorian + Hijri calendar audit completed against the existing Riverpod calendar controller, calendar picker, and `hijri` package integration without replacing the existing architecture.

- Added independent known Umm al-Qura reference-date validation around Hijri month/year boundaries.
- Added explicit calendar-date serialization/deserialization coverage using the canonical `YYYY-MM-DD` representation, verifying that timezone information cannot shift the restored civil date.
- Added Gregorian leap-day rendering coverage.
- Added Gregorian December → January navigation coverage.
- Added Hijri Ramadan → Shawwal navigation coverage.
- Added inclusive range coverage across a Gregorian year boundary.
- Added future-date and minimum-supported-date navigation boundary coverage.
- Added `docs/GREGORIAN_HIJRI_CALENDAR.md`.

## Task 8 Validation — VERIFIED

GitHub Actions run `35030188934` on commit `676e3bf65aeceb228fff77a90d81ce7eeec28784` completed successfully:

- Analyze — ✅
- Tests (Windows) — ✅
- Tests (Linux) — ✅
- Android debug APK — ✅
- Android release APK — ✅
- All workflow cleanup/post steps — ✅

The complete GitHub CI matrix passed for the final Task 8 implementation commit. Task 8 therefore meets the project completion standard.

## Known Bugs

No known blocking production defect has been identified in the current completed Task 8 audit.

## Blockers

None identified for the completed Task 8 scope.

## Remaining Work

Tasks 9–15 remain for their own dedicated audits/implementation verification. Task 9 is the next task.

## Last Verified

Task 8 implementation verified on `676e3bf65aeceb228fff77a90d81ce7eeec28784` by GitHub Actions run `35030188934` on 2026-09-16.

## Next Recommended Step

Proceed to Task 9 — Reminders / Notifications (optional).

## Task Completion Standard

Every task follows:

**Audit/Implement agreed scope → Fix real issues → Test completely → Update PROJECT_STATUS.md → Commit → Push → Open/update PR → Run the full GitHub CI matrix → Mark ✅ COMPLETE only after all required CI checks are green.**

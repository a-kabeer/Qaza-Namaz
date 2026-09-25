# Qaza-Namaz — Complete Project Improvement & Hardening Plan

## 1. Objective

Transform the current Qaza-Namaz application from a technically strong Qaza ledger into a:

- simple and intuitive daily-use Qaza companion
- privacy-conscious and secure application
- reliable offline-first application
- transparent and trustworthy calculator
- accessible English/Urdu experience
- production-ready Android release
- maintainable codebase with one current source of truth

The implementation must preserve the existing Drift, Offline-First, Firebase Sync, Guest Migration, Calculator, Availability, Skeleton Loading, and Knowledge Base architecture unless a specific defect proves that a component must be redesigned.

---

# 2. Execution Principles

## Preserve existing strengths

Do not rebuild unnecessarily:

- Drift/SQLite database
- Offline-first repository
- Sync outbox
- Sync engine
- Guest migration
- Qaza availability service
- Calculator state architecture
- Determinate bulk insertion
- Keyset pagination
- Skeleton/shimmer system
- Knowledge Base parser
- Existing accessibility foundation

## New implementation principles

Every change should satisfy:

1. Offline-first behavior remains intact.
2. User data is never silently deleted.
3. Destructive actions require explicit confirmation.
4. Large operations show determinate progress.
5. User-facing technical errors are translated into plain language.
6. All user-facing strings are localized.
7. Gregorian dates remain authoritative; Hijri remains secondary.
8. Light/dark/RTL/accessibility must work for every new UI.
9. Changes must be covered by regression tests.
10. Production builds must be tested, not only debug builds.

---

# 3. Phase 0 — Baseline & Audit Lock

## Goal

Create a reliable baseline before making changes.

### Tasks

-  Freeze current `main` as audit baseline.
-  Record current Git SHA.
-  Record Flutter version.
-  Record Dart version.
-  Record Android Gradle Plugin version.
-  Record Gradle version.
-  Record package/application ID.
-  Record current Firebase project configuration.
-  Record current test counts.
-  Record current CI status.
-  Create `PROJECT_STATUS.md` as the current source of truth.
-  Move obsolete task/status documents into `docs/archive/`.
-  Document known limitations that require physical device testing.

### Exit criteria

- Baseline builds successfully.
- Analyze passes.
- Linux tests pass.
- Windows tests pass.
- Android debug build passes.
- Current CI state is recorded.

---

# 4. Phase 1 — Production Security & Release Hardening

## Priority: P0

This phase must be completed before public production release.

## 4.1 Firestore rules hardening

### Tasks

-  Validate exact document fields.
-  Reject unexpected fields.
-  Validate field types.
-  Validate `userId`.
-  Validate record ID.
-  Validate allowed prayer types.
-  Validate `pending/completed` status.
-  Validate `completedAt` consistency.
-  Prevent modification of immutable record fields.
-  Validate timestamps.
-  Harden `qazaChanges`.
-  Harden `syncMetadata`.
-  Add negative security tests.

### Tests

-  User cannot read another user's records.
-  User cannot write another user's records.
-  User cannot change immutable fields.
-  Invalid status rejected.
-  Invalid prayer type rejected.
-  Invalid schema rejected.
-  Invalid sync generation rejected.

---

## 4.2 Firebase App Check

### Tasks

-  Add Firebase App Check.
-  Configure Play Integrity for Android.
-  Configure debug provider for development.
-  Add App Check initialization.
-  Monitor verification results.
-  Enable enforcement after validation.

### Exit criteria

Unauthenticated or unverified application clients cannot freely abuse Firebase resources beyond the intended security model.

---

## 4.3 Production release signing

### Tasks

-  Configure production keystore.
-  Store signing secrets only in GitHub encrypted secrets.
-  Configure release signing Gradle configuration.
-  Add SHA-1 and SHA-256 production fingerprints.
-  Verify Firebase Android configuration against release certificate.
-  Build signed release AAB.
-  Verify AAB signature.
-  Upload release AAB artifact in CI.

### CI requirement

Development PR:

```text
Analyze
Tests
Debug build

```

Release branch/tag:

```text
Analyze
Tests
Debug build
Release AAB
Signing verification
Security checks

```

---

## 4.4 Android target/SDK verification

### Tasks

-  Explicitly inspect resolved compile SDK.
-  Explicitly inspect resolved target SDK.
-  Ensure target SDK meets current Google Play requirements.
-  Add a CI assertion for the target SDK.
-  Document min/target/compile SDK policy.

---

## 4.5 Android backup/privacy hardening

### Tasks

-  Review Android Auto Backup behavior.
-  Add `dataExtractionRules.xml`.
-  Decide what local Qaza data should be backed up.
-  Protect sensitive application data.
-  Document restore behavior.
-  Test fresh install + restore scenarios.

---

# 5. Phase 2 — Privacy & Account Safety

## Priority: P0/P1

## 5.1 Local data protection

### Tasks

-  Evaluate database encryption.
-  Protect encryption key using Android secure storage/Keystore.
-  Encrypt sensitive local database data.
-  Protect backup files.
-  Avoid storing sensitive diagnostics unnecessarily.
-  Review sync outbox error persistence.

---

## 5.2 App Lock

Add:

```text
Settings
→ Privacy & Security
→ App Lock

```

### Options

```text
Use device authentication

Lock immediately
1 minute
5 minutes
Never

```

### Tasks

-  Detect biometric/device authentication availability.
-  Add lock controller.
-  Lock app after configured timeout.
-  Lock on resume when required.
-  Prevent data visibility while locked.
-  Add accessibility support.
-  Add tests.

---

## 5.3 Account data transparency

Account page should show:

```text
Account
Email
Cloud backup
Last sync
Qaza count

Export data
Delete cloud data
Sign out

```

### Tasks

-  Add clear sync status.
-  Add explicit data-management actions.
-  Add confirmation for cloud deletion.
-  Explain what is local vs cloud.

---

# 6. Phase 3 — Navigation & Information Architecture

## Priority: P1

## Current problem

Qaza is one of the core functions but is not a primary bottom-navigation destination.

## Target navigation

```text
Home
Qaza
Knowledge
Settings

```

Calculator should remain a contextual tool.

## Tasks

-  Add Qaza to main navigation.
-  Keep Calculator accessible from Home.
-  Keep Calculator accessible from Qaza.
-  Keep FAB behavior consistent.
-  Preserve state when switching tabs.
-  Preserve scroll positions.
-  Prevent duplicate pushed copies of workspace screens.
-  Verify Android Back.
-  Verify gesture Back.
-  Verify predictive Back where supported.
-  Verify nested flow Back.

## Exit criteria

A first-time user can reach:

```text
Home → Qaza
Home → Calculator
Home → Knowledge
Home → Settings

```

without guessing where the feature is located.

---

# 7. Phase 4 — Home Experience

## Priority: P1

## Goal

Home should answer:

1. How much Qaza remains?
2. What should I do next?
3. What is today's progress?

## Add

### Progress overview

Keep current overall progress bar.

### Today's progress

Example:

```text
Today
4 / 5 completed
1 remaining

```

### Next Qaza

```text
Fajr
15 January 2010

[ Complete next Qaza ]

```

### Qaza plan

```text
5 per day
Estimated completion...

```

### View all

```text
[ View All Qaza ]

```

### Tasks

-  Add daily progress model.
-  Add next-Qaza provider.
-  Add completion action.
-  Add Qaza plan state.
-  Add completion estimate.
-  Add progress persistence.
-  Add empty/loading/error states.
-  Add tests.

---

# 8. Phase 5 — Qaza Tracker UX

## Priority: P1

### 8.1 Record actions

Add:

```text
Mark complete
Edit
Delete

```

### Requirements

-  Edit original date.
-  Edit prayer type.
-  Prevent duplicate combination.
-  Confirm destructive delete.
-  Support offline changes.
-  Queue sync operations.
-  Resolve conflicts safely.

---

## 8.2 Undo completion

After completion:

```text
25 Qaza completed

[ Undo ]

```

### Tasks

-  Add reversible completion state.
-  Support single completion.
-  Support bulk completion.
-  Persist undo window appropriately.
-  Test offline/online behavior.

---

## 8.3 Selection improvements

Add:

```text
Select all visible
Clear selection
Complete selected

```

For large results:

```text
Select all visible
Select all matching

```

with explicit confirmation for very large operations.

---

## 8.4 Sorting

Add:

```text
Oldest first
Newest first

```

Keep deterministic ordering:

```text
originalDate
then id

```

---

## 8.5 Empty/filter UX

Make filter state obvious:

```text
Pending
Fajr
January 2010

```

Add a compact active-filter summary and one-tap reset.

---

# 9. Phase 6 — Add Qaza Flow

## Priority: P1

Current three-step structure remains:

```text
1 Dates
2 Missed Prayers
3 Review & Add

```

## Improvements

### Step 1

-  Explain date-range inclusivity.
-  Improve selected-date summary.
-  Improve availability visual language.
-  Keep Gregorian primary.
-  Keep Hijri secondary.
-  Keep month/year navigation.
-  Ensure cross-month/year range selection.

### Step 2

-  Improve unavailable-prayer explanation.
-  Add per-prayer available-date counts.
-  Make partial availability visually obvious.
-  Add “Select all available”.
-  Add “Clear all”.

### Step 3

-  Add final confirmation summary.
-  Show existing vs new records.
-  Show exact number being created.
-  Show progress during large insertion.
-  Prevent duplicate submissions.
-  Show recoverable errors.

---

# 10. Phase 7 — Calculator UX & Trust

## Priority: P1

## 10.1 Full localization

Remove every hardcoded user-visible string.

Audit:

```text
Buttons
Errors
Dialogs
Helper text
SnackBars
Semantics
Tooltips
Validation

```

---

## 10.2 Calculation explanation

Add:

```text
How was this calculated?

```

Show:

```text
DOB
Baligh date
Prayer start date
Qaza period
Number of days
Daily prayer count
Witr
Estimated total
Existing records
New records

```

---

## 10.3 Methodology page

Add:

```text
Calculator methodology

```

Explain:

- date boundaries
- Baligh assumptions
- prayer count
- Witr treatment
- inclusive/exclusive date logic
- duplicate handling

Where jurisprudential differences matter, explicitly document them rather than hiding them inside the calculator.

---

## 10.4 Calculator workflow

Preserve:

```text
Preflight
→ Confirmation
→ Batch insert
→ Determinate progress
→ Success

```

Improve:

-  More readable result card.
-  Stronger explanation before bulk insertion.
-  Better empty/zero-result state.
-  Cancel-safe behavior.
-  Retry behavior.
-  Progress persistence/state handling.

---

# 12. Phase 9 — Knowledge Base

## Priority: P1/P2

Current architecture remains.

## Add

-  Save/bookmark article.
-  Recently viewed.
-  Share article.
-  Copy article text.
-  Source metadata.
-  Last reviewed date.
-  Methodology/authority indicator where appropriate.
-  Search result highlighting.
-  Better empty/search states.

## Content governance

Every article should eventually support:

```text
Source
Book
Reference
Reviewed
Last updated

```

Avoid presenting disputed jurisprudential details as universally settled without qualification.

---

# 13. Phase 10 — Import/Export & Backup UX

## Priority: P1

## Export

Add:

```text
Export backup

Records
12,450

Format
JSON

[ Export ]

```

Future:

```text
Encrypted backup

```

## Import

Use:

```text
Select file
↓
Analyze
↓
Preview
↓
Confirm
↓
Import
↓
Result

```

Preview:

```text
12,450 records

8,200 new
4,100 already present
150 will become completed

```

### Tasks

-  Large-file progress.
-  Duplicate handling.
-  Invalid-file explanation.
-  UTF-8/Urdu regression tests.
-  Import cancellation.
-  Recovery from partial failure.
-  Encrypted backup design.

---

# 14. Phase 11 — Accessibility & Localization Certification

## Priority: P1

Run a complete matrix:

```text
English
Urdu
RTL
Light
Dark
System theme
100% text
130% text
150% text
200% text
TalkBack
Keyboard
Reduced motion
High contrast

```

## Specific tasks

-  Minimum 48dp interactive targets.
-  Calendar cells ≥48dp touch target.
-  Review all Semantics.
-  Review focus order.
-  Review keyboard navigation.
-  Verify Urdu Nastaliq line height.
-  Verify no clipped text.
-  Verify RTL mirroring.
-  Verify translated error messages.

---

# 15. Phase 12 — UX Error & Recovery System

## Goal

Every failure should answer:

```text
What happened?
Is my data safe?
What should I do?

```

Replace raw technical errors with:

```text
Couldn't finish syncing.

Your Qaza records are still safe on this device.
We'll try again automatically.

[ Try now ]

```

Technical detail becomes secondary.

## Apply to

-  Authentication
-  Google Sign-In
-  Sync
-  Import
-  Export
-  Calculator
-  Add Qaza
-  Database errors
- [Permission failures

---

# 16. Phase 13 — Production Observability

## Priority: P1

Add Firebase Crashlytics or equivalent production diagnostics.

Track only non-sensitive information.

### Monitor

```text
Crash rate
Authentication failures
Notification initialization failures
Notification scheduling failures
Sync failures
Import failures
Database migration failures

```

Never log:

- complete Qaza records
- user prayer history
- private content
- authentication credentials/tokens

---

# 17. Phase 14 — Automated Quality Gates

## CI must eventually include

```text
Formatting
Static analysis
Unit tests
Widget tests
Accessibility tests
Database tests
Sync tests
Guest migration tests
Calculator tests
Notification tests
Linux tests
Windows tests
Android debug build
Android release AAB
Security rule tests

```

## Release-only checks

```text
Release signing
Target SDK
Firebase configuration
OAuth configuration
App Check configuration
AAB verification

```

---

# 18. Phase 15 — Performance Certification

Create test datasets:

```text
100 records
1,000 records
10,000 records
50,000 records
100,000 records

```

Measure:

-  Home load time.
-  Qaza tracker initial load.
-  Scrolling.
-  Filtering.
-  Sorting.
-  Availability analysis.
-  Calculator preflight.
-  Bulk add.
-  Bulk completion.
-  Sync batching.
-  App restart recovery.

No feature should materialize the complete ledger in the UI unnecessarily.

---

# 19. Phase 16 — UX Acceptance Journey

The final application must pass these journeys.

## First-time user

```text
Splash
→ Welcome
→ Google / Guest
→ Home

```

## Manual Qaza

```text
Home
→ Add Qaza
→ Dates
→ Prayer
→ Review
→ Add
→ Success
→ Home

```

## Calculator

```text
Home
→ Calculator
→ DOB
→ Baligh
→ Prayer start
→ Result
→ Explain calculation
→ Preflight
→ Confirm
→ Progress
→ Success

```

## Daily completion

```text
Home
→ Next Qaza
→ Complete
→ Next oldest automatically shown

```

## Tracker

```text
Qaza
→ Filter
→ Select
→ Complete
→ Undo

```

## Guest conversion

```text
Guest
→ Sign in
→ Existing account detected
→ Merge / Use account / Keep guest

```

## Offline

```text
Offline
→ Add Qaza
→ Complete Qaza
→ App restart
→ Data remains
→ Reconnect
→ Sync

```

---

# 20. Final Release Gate

The project is ready for public release only when:

-  Firestore rules hardened.
-  Security tests pass.
-  App Check configured.
-  Production signing works.
-  Signed AAB builds successfully.
-  Target SDK verified.
-  Android backup strategy finalized.
-  Notification device QA passed.
-  Google Sign-In device QA passed.
-  Guest migration device QA passed.
-  Import/export QA passed.
-  English localization complete.
-  Urdu localization complete.
-  RTL QA passed.
-  Accessibility QA passed.
-  Large dataset QA passed.
-  Crash reporting enabled.
-  Privacy policy available.
-  Terms available.
-  Account/data deletion process documented.
-  Current project documentation updated.
-  Release checklist signed off.

---

# 21. Recommended Implementation Order

## Sprint 1 — Security & Release Foundation

```text
Firestore hardening
App Check
Production signing
Target SDK verification
Backup rules
Security tests

```

## Sprint 2 — Navigation & Daily UX

```text
Qaza primary navigation
Next Qaza
Today progress
Qaza plan foundation
Tracker actions
Undo

```

## Sprint 3 — Calculator & Add Qaza

```text
Localization cleanup
Calculation explanation
Methodology
Large-operation UX
Add Qaza progress

```

## Sprint 4 — Privacy & App Lock

```text
App Lock
Account transparency
Privacy controls

```

## Sprint 5 — Knowledge & Data Management

```text
Knowledge bookmarks
Recently viewed
Sharing
Import preview
Export improvements
Encrypted backup design

```

## Sprint 6 — Certification

```text
Accessibility
RTL
Large text
Performance
Crash reporting
Integration testing
Release AAB
Production smoke tests

```

---

# 22. Status Tracking Format

Use this structure for every implementation task:

| TaskStatusTestsCIDevice QANotes |             |   |   |   |                 |
| ------------------------------- | ----------- | - | - | - | --------------- |
| Firestore hardening             | Not started | — | — | — | P0              |
| App Check                       | Not started | — | — | — | P0              |
| Production signing              | Not started | — | — | — | P0              |
| Qaza navigation                 | Not started | — | — | — | P1              |
| Next Qaza                       | Not started | — | — | — | P1              |
| Qaza plan                       | Not started | — | — | — | P1              |
| Tracker edit/delete             | Not started | — | — | — | P1              |
| Undo completion                 | Not started | — | — | — | P1              |
| Calculator explanation          | Not started | — | — | — | P1              |
| Localization cleanup            | Not started | — | — | — | P1              |
| App Lock                        | Not started | — | — | — | P1              |
| Import/export UX                | Not started | — | — | — | P1              |
| Knowledge improvements          | Not started | — | — | — | P2              |
| Accessibility certification     | Not started | — | — | — | P1              |
| Performance certification       | Not started | — | — | — | P1              |
| Crash reporting                 | Not started | — | — | — | P1              |

---

# 23. Definition of Done

A task is not considered complete merely because the code compiles.

Each task must satisfy:

```text
Implementation
    ↓
Unit/widget tests
    ↓
Regression tests
    ↓
Analyze
    ↓
CI
    ↓
Device QA where required
    ↓
UX review
    ↓
Documentation
    ↓
Merge

```

For security-sensitive changes:

```text
Implementation
    ↓
Positive tests
    ↓
Negative/security tests
    ↓
CI
    ↓
Production configuration verification

```

---

# 24. Final Target Architecture

The target product should evolve toward:

```text
                   QAZA-NAMAZ
                       │
        ┌──────────────┼──────────────┐
        │              │              │
      Home           Qaza         Knowledge
        │              │              │
        │              │              ├─ Search
        │              │              ├─ Masail
        │              │              ├─ Mugalat
        │              │              └─ Sources
        │              │
        ├─ Today's     ├─ Pending
        │  progress     ├─ Completed
        ├─ Next Qaza    ├─ Filters
        ├─ Qaza plan    ├─ Edit
        └─ Calculator   └─ Complete
                       │
                    Settings
                       │
          ┌────────────┼─────────────┐
          │            │             │
       Account      Privacy       Backup
       Notifications Calculation   Help/About

```

The application should feel **calm, predictable, private, and low-friction**, with the technical complexity hidden underneath the user experience.

# Highest-priority first action

Start with:

```text
P0 — Production Security & Release Hardening

```

then immediately move to:

```text
P1 — Qaza Navigation + Next Qaza + Completion UX

```

before adding secondary features such as Knowledge Base bookmarks or analytics.
# QAZA NAMAZ ANDROID APP

## Master Development, Architecture, Implementation & Review Prompt

You are responsible for helping me build this complete Android application from start to production.

I am a complete beginner in Flutter development.

The application will be built with:

* Flutter
* Dart
* Firebase Authentication
* Google Sign-In
* Cloud Firestore
* Local/offline persistence where appropriate
* GitHub for source control
* Google Stitch for frontend/UI design

I will use Google Stitch to create/design the frontend screens. Your responsibility is primarily the **backend, architecture, data model, business logic, Firebase integration, synchronization, validation, testing, project structure, and technical review**.

Do NOT assume that I understand Flutter, Firebase, Git, databases, authentication, APIs, or architecture.

Explain things step-by-step when I need to perform something manually.

---

# 1. PRODUCT PURPOSE

This is a Qaza Namaz tracking application.

The application allows a user to:

1. Sign in directly with their Google account.
2. Record which historical dates had missed/Qaza prayers.
3. Use both Gregorian and Hijri calendars.
4. Select individual dates or date ranges.
5. Track six completely independent prayer types:

   * Fajr
   * Zuhr
   * Asr
   * Maghrib
   * Isha
   * Witr
6. View separate Qaza counts for each prayer.
7. Complete Qaza prayers through a normal date-based workflow.
8. Complete Qaza prayers through a prayer-specific workflow.
9. Select multiple pending dates for the same prayer and complete them together.
10. Automatically decrease the corresponding pending count.
11. Preserve the original Qaza date.
12. Preserve the actual date/time when the Qaza was completed.
13. View complete history.
14. View progress.
15. Delete/reinstall the app and restore the same data on another phone after signing in with the same Google account.

---

# 2. CRITICAL PRODUCT PRINCIPLE

The application must NOT be designed as a simple counter app.

The source of truth must be individual Qaza records.

Do NOT make:

Fajr = 247

the primary database record.

Instead, store individual Qaza records such as:

Prayer: Fajr
Original date: 2024-01-01
Status: pending

The Fajr count must be calculated from pending Fajr records.

This prevents counter/history/data inconsistencies.

---

# 3. SIX INDEPENDENT PRAYERS

The application must always treat these as six separate prayer types:

1. Fajr
2. Zuhr
3. Asr
4. Maghrib
5. Isha
6. Witr

Witr MUST NOT be merged into Isha.

Each prayer must have its own:

* Qaza records
* Pending count
* Completed count
* History
* Progress
* Prayer-wise selection
* Completion workflow

---

# 4. TASK SYSTEM

The entire project is divided into 15 major tasks.

Never assume a task is complete merely because some code exists.

A task is COMPLETE only when:

* implementation exists
* required functionality works
* relevant tests pass
* no known blocking bugs remain
* architecture is consistent
* code is integrated properly
* GitHub contains the completed work
* documentation/status is updated

For every review, report:

STATUS:

* ✅ COMPLETE
* 🟡 PARTIALLY COMPLETE
* 🔴 NOT COMPLETE
* ⚠️ BLOCKED

Never falsely mark a task complete.

---

# TASK 1 — PRODUCT WORKFLOW

Status baseline: DEFINED

Implement and preserve the following workflow.

## Calendar/date-based workflow

User selects:

* Gregorian or Hijri calendar
* single date or date range

Then identifies which prayers were missed on those dates.

Example:

2024-01-01:

* Fajr → Qaza
* Zuhr → Qaza
* Asr → not Qaza
* Maghrib → not Qaza
* Isha → Qaza
* Witr → Qaza

Each selected Qaza becomes an individual pending record.

## Qaza completion workflow

User selects:

1. date on which they are performing Qaza
2. prayer type

Example:

Completion date:
2026-09-13

Prayer:
Fajr

The application should identify the appropriate pending Fajr Qaza.

Default behavior:

oldest pending Qaza first.

When completed:

* status becomes completed
* original date remains unchanged
* completion date/time is stored
* pending Fajr count decreases automatically

## Prayer-wise workflow

Separate "Namaz-wise" section.

User selects:

Fajr

Then sees pending Fajr dates:

* 01 Jan 2024
* 02 Jan 2024
* 03 Jan 2024
* 04 Jan 2024
* 05 Jan 2024

User can select multiple dates.

Example:

☑ 01 Jan 2024
☑ 02 Jan 2024
☑ 03 Jan 2024
☑ 04 Jan 2024
☑ 05 Jan 2024

Then:

"Mark as Completed"

All five selected Fajr records become completed.

Fajr count decreases by 5.

---

# TASK 2 — GOOGLE AUTHENTICATION + CLOUD PERSISTENCE

Status baseline: DEFINED

Use:

Firebase Authentication
+
Google Sign-In
+
Cloud Firestore

Google account is the user's identity.

Firestore stores the user's Qaza data.

Required behavior:

Phone A:

* Install app
* Google Sign-In
* create/use account
* create Qaza data

User deletes app.

Phone B:

* install app
* Sign in with same Google account

Application must retrieve the user's previous Qaza data.

No custom backend server should be required.

Do NOT confuse Google Sign-In with Google Drive storage.

Google authentication identifies the user.

Firestore stores the application's data.

---

# TASK 3 — UI/UX CONTRACT

The frontend will be designed with Google Stitch.

Your responsibility:

* define backend requirements for every screen
* define data needed by every screen
* define states
* define loading/error/empty states
* ensure Stitch-generated frontend can connect cleanly to the backend

Expected major screens:

1. Splash
2. Welcome
3. Google Sign-In
4. First-time setup
5. Home
6. Calendar
7. Date details
8. Date-range selection
9. Qaza completion
10. Namaz-wise
11. Prayer-specific date selection
12. History
13. Progress
14. Settings
15. Account
16. Sync status
17. Error/offline states

Do not rebuild frontend unnecessarily if Stitch already provides the UI.

---

# TASK 4 — DATABASE ARCHITECTURE

Design and implement a production-quality Firestore schema.

Recommended conceptual structure:

users/{uid}

qaza_records/{recordId}

or another architecture if your technical audit proves a better structure.

Every Qaza record must contain enough information to identify:

* user
* prayer type
* original Qaza date
* status
* completion date/time
* creation date/time
* update date/time

Avoid storing redundant counters as the primary source of truth.

---

# TASK 5 — OFFLINE-FIRST ARCHITECTURE

The application should remain useful when temporarily offline.

Target architecture:

UI
↓
State Management
↓
Repository
↓
Local persistence/cache
↓
Firestore synchronization

Requirements:

* read cached data when offline
* allow appropriate local changes offline
* synchronize when internet returns
* avoid duplicate records
* avoid accidental double completion
* show sync state where useful

Do not blindly make every UI action directly call Firestore.

Use a clean repository/service architecture.

---

# TASK 6 — AUTHENTICATION LIFECYCLE

Implement and test:

* first Google login
* returning Google login
* logout
* login cancellation
* authentication failure
* network failure
* account switching
* app restart
* token/session restoration
* new device login

Never mix data between Google accounts.

Every user's data must be isolated using Firebase Authentication identity.

---

# TASK 7 — QAZA BUSINESS LOGIC

Implement the core domain logic.

Rules:

* six independent prayers
* individual Qaza records
* pending/completed states
* counts derived from records
* oldest pending first by default
* multiple completion
* date-based completion
* prayer-wise completion
* no accidental duplicate records
* no negative counts

Example:

Fajr:
247 pending

Complete 5:

Fajr:
242 pending

The UI should never manually decrement a counter independently of the underlying records.

---

# TASK 8 — GREGORIAN + HIJRI CALENDAR

Implement calendar support.

Requirements:

* Gregorian calendar
* Hijri calendar
* switching between them
* single date selection
* multi-date selection
* date range selection
* month navigation
* selected-date state
* Qaza indicators
* pending/completed indicators

Document the Hijri calculation method used.

Do not silently assume that every Hijri calculation method will match every regional moon-sighting convention.

The calendar implementation must be tested carefully around:

* month boundaries
* year boundaries
* leap years
* Hijri conversion
* date ranges
* timezone behavior

---

# TASK 9 — REMINDERS / NOTIFICATIONS

Treat this as optional but recommended.

Potential features:

* daily Qaza reminder
* configurable reminder time
* enable/disable
* notification permission handling
* graceful behavior when notifications are unavailable

Do not make reminders mandatory.

---

# TASK 10 — MULTI-DEVICE SYNCHRONIZATION

This is critical.

A user may sign in with the same Google account on multiple phones.

Do NOT synchronize only counters.

Synchronize individual Qaza records.

Example:

Phone A:
Fajr record #123 → completed

Phone B:
must eventually see:
Fajr record #123 → completed

Prevent:

* duplicate completion
* duplicate Qaza creation
* counter mismatch
* overwriting newer data with stale data

Define and document the conflict-resolution strategy.

---

# TASK 11 — SECURITY + PRIVACY

Firestore security rules must guarantee:

User A cannot read User B's data.

User A cannot write User B's data.

Authentication must be required for protected user data.

Review:

* Firestore rules
* Firebase configuration
* client-side assumptions
* sensitive data exposure
* logging
* debug information
* production configuration

Do not put private secrets/API secrets directly into source code.

---

# TASK 12 — EXPORT / IMPORT

Implement or prepare architecture for:

Export My Data

Import My Data

Potential backup format:

JSON

The exported data should preserve:

* prayer type
* original date
* status
* completion date/time
* relevant metadata

The export must be useful if the user ever wants to migrate away from the application.

---

# TASK 13 — SETTINGS + ACCOUNT MANAGEMENT

Settings should support:

Account

* Google account
* sign out

Data

* sync status
* last synchronization
* export
* import
* delete data

App

* theme
* language
* notifications

About

* privacy policy
* terms
* app version

Clearly distinguish:

"Delete local data"

from:

"Delete cloud/account data"

Do not accidentally delete a user's entire account when they only want to clear local cache.

---

# TASK 14 — TESTING / QA

Create meaningful tests for:

## Authentication

* login
* logout
* account switching
* cancelled login

## Qaza records

* create
* update
* complete
* duplicate prevention
* six prayer types
* Witr independently
* multiple dates
* range selection

## Counters

* pending count
* completed count
* total count
* zero state
* no negative values

## Calendar

* Gregorian
* Hijri
* date conversion
* range
* month navigation

## Offline

* create while offline
* complete while offline where supported
* reconnect
* sync

## Multi-device

Phone A → change data
Phone B → login/sync
Verify consistency.

## Regression

Whenever a task is completed, make sure previous tasks still work.

---

# TASK 15 — PRODUCTION RELEASE

Before release audit:

* release configuration
* Firebase production configuration
* Google Sign-In configuration
* Firestore rules
* authentication
* offline behavior
* crash handling
* app icon
* splash
* versioning
* privacy policy
* terms
* Play Store requirements
* screenshots
* app description
* internal testing
* release build

Never declare production-ready merely because the app compiles.

---

# 5. GITHUB WORKFLOW

The GitHub repository is the project source of truth.

Before making changes:

1. inspect repository
2. identify current branch
3. inspect current architecture
4. inspect existing changes
5. do not overwrite unrelated work
6. determine what task is currently implemented

After changes:

1. run relevant tests
2. inspect git diff
3. verify no accidental files
4. commit logically
5. push if authorized
6. update project status documentation

Use clear commit messages.

Example:

task-07: implement qaza completion logic

---

# 6. PROJECT STATUS DOCUMENT

Maintain a project status document in the repository:

PROJECT_STATUS.md

It must contain:

# Qaza Namaz App — Project Status

## Current Task

Task X

## Overall Progress

X / 15

## Task Status

Task 1 — COMPLETE
Task 2 — COMPLETE
Task 3 — IN PROGRESS
...

## Completed Work

...

## Remaining Work

...

## Known Bugs

...

## Blockers

...

## Last Verified

...

## Next Recommended Step

...

Update this document whenever a task meaningfully changes.

---

# 7. REVIEW COMMAND

Whenever I say:

"Review project"

you must inspect the actual GitHub repository.

Do NOT rely only on previous conversation.

Review:

* repository structure
* Flutter project
* pubspec.yaml
* Firebase configuration
* authentication
* Firestore integration
* models
* repositories
* services
* state management
* calendar implementation
* business logic
* tests
* documentation
* git status/history where available

Then compare the implementation against all 15 tasks.

Return:

## PROJECT STATUS

Task 1 — ✅
Task 2 — 🟡
Task 3 — 🔴
...

Then:

## COMPLETED

...

## PARTIALLY COMPLETED

...

## MISSING

...

## BUGS

...

## ARCHITECTURE ISSUES

...

## SECURITY ISSUES

...

## NEXT TASK

...

Never guess.

If something cannot be verified from the repository, explicitly say:

"NOT VERIFIED"

---

# 8. REVIEW TASK COMMAND

Whenever I say:

"Review Task 7"

only audit Task 7 deeply, but also check for regressions caused by Task 7.

Report:

* requirements
* implementation found
* missing implementation
* bugs
* tests
* recommendation
* completion percentage

---

# 9. BEGINNER MODE

I am a beginner.

Whenever I need to perform something manually, give instructions like:

STEP 1
Open...

STEP 2
Click...

STEP 3
Run...

STEP 4
Verify...

Tell me exactly:

* what file
* what command
* where to paste
* what result I should see

Do not assume advanced knowledge.

Do not give me ten unrelated tasks at once.

Work incrementally.

---

# 10. DO NOT DESTROY EXISTING WORK

Before changing code:

* inspect first
* understand first
* reuse existing infrastructure
* avoid unnecessary rewrites

Do not introduce a new architecture merely because it is your personal preference.

If an existing implementation is good, preserve it.

If it is bad, explain why before replacing it.

---

# 11. STITCH FRONTEND CONTRACT

The frontend may be generated by Google Stitch.

When reviewing or implementing backend functionality, provide a clear contract for the frontend:

* required data
* field names
* states
* actions
* validation
* loading
* error
* empty
* success
* sync state

Backend logic must not depend on fragile UI assumptions.

The Flutter application should remain maintainable even if the Stitch-generated UI is later redesigned.

---

# 12. DATA INTEGRITY RULES

These are non-negotiable.

1. Never allow negative Qaza counts.
2. Never complete a nonexistent Qaza record.
3. Never create duplicate Qaza records for the same user/prayer/original date unless explicitly allowed by the business rules.
4. Witr remains independent.
5. Original Qaza date must never be replaced by completion date.
6. Completion date/time must be stored separately.
7. Counters must derive from records.
8. Cloud and local state must eventually converge.
9. One user's data must never appear under another user's account.
10. Deleting/reinstalling the app must not destroy cloud data.

---

# 13. EXPECTED FINAL PRODUCT

The finished application should provide:

Google Sign-In
↓
User account
↓
Qaza setup
↓
Gregorian/Hijri Calendar
↓
Date/date-range Qaza recording
↓
Six independent prayer counts
↓
Normal Qaza completion
↓
Prayer-wise Qaza completion
↓
Multiple-date completion
↓
Automatic count updates
↓
History
↓
Progress
↓
Offline capability
↓
Cloud synchronization
↓
New-device restoration
↓
Export/import
↓
Settings
↓
Production-ready security/testing

---

# 14. HOW TO REPORT PROGRESS

Every time I ask:

"status"

respond with:

## Overall

X / 15 tasks complete

## Tasks

1. Product Workflow — ✅
2. Firebase/Auth — ✅
3. UI/UX Contract — 🟡
4. Database — 🔴
5. Offline Sync — 🔴
6. Authentication Lifecycle — 🔴
7. Qaza Logic — 🔴
8. Calendar — 🔴
9. Notifications — 🔴
10. Multi-device Sync — 🔴
11. Security — 🔴
12. Export/Import — 🔴
13. Settings — 🔴
14. Testing — 🔴
15. Release — 🔴

## Current Focus

...

## Next Step

...

Do not count planned work as completed work.

---

# 15. FIRST ACTION

When this master prompt is first provided:

DO NOT immediately start writing a large amount of code.

First:

1. Locate the connected GitHub repository.
2. Inspect the repository.
3. Determine whether it is an existing Flutter project or empty/new project.
4. Inspect pubspec.yaml.
5. Inspect current source structure.
6. Inspect Firebase configuration if present.
7. Inspect Git history/current branch.
8. Determine which of the 15 tasks already exist.
9. Create/update PROJECT_STATUS.md.
10. Report the baseline audit.

Then recommend the next single task.

Because I am a beginner, do not jump ahead without establishing the baseline.

---

# FINAL RULE

You are responsible for guiding this project from beginner setup to production.

Always:

AUDIT → PLAN → IMPLEMENT → TEST → VERIFY → UPDATE STATUS → NEXT TASK

Never:

GUESS → CODE EVERYTHING → CLAIM COMPLETE

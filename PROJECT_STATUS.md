# Qaza Namaz — Master Improvement & Hardening Status

> **Canonical execution tracker for the attached Complete Project Improvement & Hardening Plan.**
> This section supersedes conflicting or point-in-time status notes later in this file.
>
> Updated: **2026-09-20**
> Working branch: `hardening/security-release-baseline-20260920`
> Baseline commit: `99f8c29762764d8ae05307bebc5fc01885525212`

## Current implementation pass

The highest-priority P0 security/release foundation has now been implemented on the working branch:

- Firebase App Check activation added immediately after Firebase initialization.
- Firestore rules now validate the Qaza record schema, ownership, allowed prayer/status values, completion consistency, timestamps, immutable fields, sync generation, change-log schema, and sync-state schema.
- Positive/negative Firestore rules smoke tests added for cross-user access and malformed writes.
- Android compile/target SDK is explicitly set to API 36.
- Release signing no longer falls back to the debug key; CI can inject the production keystore through GitHub encrypted secrets.
- Android CI now asserts the release policy and builds/uploads a release **AAB** when production signing secrets are configured.
- Android backup/data-extraction policies are wired with client-side-encryption requirements for cloud backup and no silent device-to-device transfer of the local Qaza database.
- The existing V2 architecture, offline-first data path, and completed Qaza UX work were preserved rather than rebuilt.

## Master plan status

| Task | Status | Tests | CI | Device QA | Notes |
| --- | --- | --- | --- | --- | --- |
| Phase 0 — Baseline & audit lock | **Complete** | Repo/status reviewed | Pending final run | — | Baseline SHA recorded |
| Firestore hardening | **Implemented** | Smoke suite added | Pending | — | P0; schema + ownership + immutable-field checks |
| Firebase App Check | **Implemented** | Startup path added | Pending | **Required** | Firebase Console Play Integrity registration/enforcement remains |
| Production release signing | **Implemented** | CI policy assertion | Pending | — | Keystore/GitHub secrets are release credentials and are not stored in repo |
| Android target SDK policy | **Complete** | CI assertion added | Pending | — | API 36 selected |
| Android backup/privacy rules | **Implemented** | Build validation pending | Pending | **Required** | Restore semantics require physical-device validation |
| Local data encryption / App Lock | **Not started** | — | — | Required | Follow-on P0/P1 privacy work |
| Account/data transparency | **Needs implementation/verification** | — | — | Required | Explicit cloud/data-management UX remains |
| Primary Qaza navigation | **Complete in existing V2 stream** | Existing regression coverage | Pending | Recommended | Preserved during this pass |
| Home daily-use improvements | **Partial** | Existing V2 coverage | Pending | Recommended | Core Home preserved; remaining plan items need verification |
| Qaza tracker actions | **Partial** | Existing tracker tests | Pending | Recommended | Core tracker/pagination complete; edit/delete/undo need explicit verification |
| Add Qaza flow | **Complete in existing V2 stream** | Existing regression coverage | Pending | Recommended | Shared availability/preflight preserved |
| Calculator trust/localization | **Partial** | Existing calculator tests | Pending | Required | Explanation/methodology and remaining literals need completion |
| Notifications | **Code complete; device QA pending** | Existing notification coverage | Pending | **Required** | Android permission/channel/reboot/device matrix still required |
| Knowledge Base | **Architecture + content present** | Existing parser/search tests | Pending | Recommended | Content governance/source review remains |
| Import/export & backup UX | **Partial** | Existing functionality needs release QA | Pending | Required | Preview/cancellation/recovery matrix remains |
| Accessibility + localization certification | **Partial** | Existing accessibility matrix | Pending | **Required** | Full English/Urdu/RTL/large-text/TalkBack matrix remains |
| Error/recovery UX | **Partial** | Existing feature tests | Pending | Recommended | Remaining technical errors need plain-language treatment |
| Production observability | **Not started** | — | — | — | Crashlytics/non-sensitive diagnostics still pending |
| Automated quality gates | **In progress** | Firestore rules gate added | Pending | — | Analyze, Linux, Windows, Android debug/release AAB are defined |
| Performance certification | **Complete in existing V2 stream** | Existing large-dataset matrix | Pending | Recommended | 1k/5k/10k paths already covered |
| End-to-end acceptance journeys | **Partial** | Regression coverage exists | Pending | **Required** | Device-only auth/notification/backup journeys remain |
| Final release gate | **Blocked** | Awaiting full gate | Awaiting PR | **Required** | App Check enforcement, signing secrets, device QA, release smoke tests |

## Definition of Done

A task is marked **complete** only after implementation, regression tests, analyze, CI, required device QA, UX review, documentation, and merge criteria are satisfied. Security-sensitive work also requires both positive and negative security coverage plus production configuration verification.

## Current blockers / external actions

1. **Firebase Console:** register/configure Android Play Integrity for Firebase App Check and enable enforcement after validation.
2. **GitHub repository secrets:** provide the production keystore and the four signing secrets required by the release workflow.
3. **Physical Android QA:** validate App Check, notifications, backup/restore behavior, authentication, guest migration, cold start, reboot, and release AAB behavior.

## Implementation commits in this pass

- `450eebcb6cf95547cb349ee8fa8653aa89ee6e0a` — add Firebase App Check dependency
- `4f719b00d7d93999e004d90791bf9552c3261b9f` — activate Firebase App Check
- `291528ad5f945d246729f6b9b31232888fafb0df` — Android API 36 + production signing configuration
- `0994f2d973cb900bf4dff7de6284331968e56452` — release policy assertion + AAB CI
- `3ce2d9874762d4992099589c8bf0787b22e21368` — Firestore schema/security hardening
- `e96a34218ff14fef6c639f646c1b921092f3d400` — Firestore rules smoke tests
- `3daf420e0e336bd8b672d67ce0e49c899c006a68` — CI Firestore rules gate
- `c44a04c9dcc9d7cdb074c687da3caed1143c42e3` — encrypted Android backup policy
- `f1d0fdf33daa3855fd05ad391ae509049e1ea259` — Android manifest backup policy wiring
- `df95e05028f63e301d31b899dc57e59e531d2f4f` — Android data extraction rules

---

# Qaza Namaz — Project Status

Canonical status document. The V2 Master Plan's 21-step implementation order is
the current stream of work; the pre-V2 reconciliation history is summarised at
the end.

## Baseline

- Local production source of truth: **Drift/SQLite**. SharedPreferences remains
  only for settings and the one-shot legacy migration.
- Production data path: `UI → Riverpod controller → QazaService → QazaRepository
  → DAO → Drift`. Verified by import sweep: no widget imports the data layer.
- Qaza identity everywhere: `userId + normalized Gregorian date + prayerType`.
- Firebase/Google authentication and optional Firestore sync are unchanged.

## V2 implementation order — progress

| # | Step | Status |
| --- | --- | --- |
| 1 | Repository / Architecture Audit | **Complete** — `docs/V2_PART1_ARCHITECTURE_AUDIT.md` |
| 2 | State Management Consolidation | **Complete** |
| 3 | Shared Qaza Preflight / Availability | **Complete** |
| 4 | Add Qaza 3-Step UX | **Complete** — `docs/ADD_QAZA_3_STEP_FLOW_STATUS.md` |
| 5 | Add Qaza Review + Batch Save | **Complete** |
| 6 | Calculator Reconciliation | **Complete** |
| 7 | Qaza Tracker UX | **Complete** |
| 8 | Home Consolidation | **Complete** |
| 9 | Dashboard Removal | **Complete** |
| 10 | Authentication / Startup Simplification | **Complete** |
| 11 | Localization (English / Urdu / Arabic-ready) | **Architecture complete** — primary surfaces translated, some screens still literal |
| 12 | RTL / Accessibility | Partial — RTL verified, accessibility labels pending on older screens |
| 13 | Theme Persistence | **Complete** |
| 14 | Data & Cloud / Bootstrap hydration | **Complete** |
| 15 | Notifications Finalization | **Complete** |
| 16 | Knowledge Base Finalization | **Architecture complete** — the bundled dataset is empty and needs authored content |
| 17 | Legacy Provider Cleanup | **Complete** |
| 18 | Performance Hardening | **Complete** — every V2 UX path validated at 1k/5k/10k |
| 19 | Regression Tests | **Complete** |
| 20 | Documentation Reconciliation | **Complete** |
| 21 | Full CI / Build Gate | Partial — everything but the Android builds passes locally; those cannot run in this environment |

## What changed in the V2 stream so far

### Navigation (plan §3, §43)

Primary destinations are now **Home · Qaza · Calculator · Settings**. Logs is no
longer a root destination; it opens from the Qaza workspace's app bar. Shell
mechanics are unchanged: `IndexedStack` with lazy mounting, reselect is a no-op,
and Back from a non-root destination returns to Home.

### Shared preflight (plan §6, §14)

`QazaAvailabilityAnalysis` is the one preflight model. It now reports
`requestedCount`, `alreadyRecorded` (pending), `alreadyCompleted`,
`blockedDateCount`, `newCandidates` and `existingCandidates`. A completed record
is derived as *already completed* rather than collapsing into *already
recorded*. Manual Add Qaza and the Calculator both run this same engine.

### Calculator (plan §5, §12, §13, §14)

- All workflow state moved into `CalculatorController`; the screen renders and
  dispatches only.
- **Witr is configured on Step 2 (Prayer History)**, never on the Result step.
- Gregorian and Hijri dates are shown together on Steps 1 and 2.
- `Add to Tracker` runs the shared preflight and shows Calculated / Already
  Recorded / Already Completed / New to Add before anything is written.
- Counts are thousands-separated (the previous formatter never matched).
- **Date-boundary contract: start inclusive, end exclusive**, documented on
  `calculateQaza` and pinned by `test/calculator_date_boundary_contract_test.dart`.

### Qaza workspace (plan §16, §17)

New `QazaTrackerController` + `QazaTrackerScreen`: aggregate progress header,
status / prayer / original-date filters, keyset pagination at 50 records per
page, loading / empty / filtered-empty / error+retry / refresh states, bounded
selection and repository-driven bulk completion. `getPage` now takes `from`/`to`
so date filtering happens in the database. The full ledger is never loaded — a
regression test fails the build if `getRecords` is called.

`NamazWiseScreen` and `PendingDatesScreen` were removed; their Witr-independence
and multi-select completion coverage moved onto the tracker.

### Home (plan §19, §20)

Home is the canonical entry point and keeps its aggregate-driven, state-dependent
CTA. The duplicate `View All Qaza` / per-prayer navigation was removed now that
Qaza is a primary destination. `lib/features/dashboard/` is deleted — it had no
production consumers.

### Legacy providers (plan §38)

`loadedRecordsProvider`, `overallProgressProvider`, `prayerProgressProvider`,
`qazaHistoryProvider`, `pendingForPrayerProvider`, `qazaRecordsProvider` and
`QazaRecordsNotifier` are all deleted. The last full-ledger read in production —
the notification controller loading every record to answer "is anything
pending" — now reads `progressSummaryProvider`.

### Localization and RTL (plan §23, §24)

Full generated-resource localization is now in place:

- `flutter_localizations` + `intl` added, `generate: true`, `l10n.yaml` driving
  `flutter gen-l10n` from `lib/l10n/app_en.arb` and `app_ur.arb`.
- `localeProvider` persists and restores the language, accepting only locales in
  `AppLocalizations.supportedLocales`. Adding Arabic means adding `app_ar.arb` —
  no application restructuring.
- `MaterialApp` declares `locale`, `localizationsDelegates` (including the
  Material, Widgets and Cupertino global delegates) and `supportedLocales`.
- **RTL is Flutter's own `Directionality`**, derived from the locale — no text
  hacks. Urdu renders right to left, verified by test; directional padding is
  used where the tracker previously hard-coded a left edge.
- Prayer names are localized through one lookup (`PrayerTypeL10n`), replacing
  the four duplicated `switch` statements the audit found. `PrayerTypeX.label`
  remains as the stable non-localized identifier for storage-adjacent code.
- Translated pluralization is in place for the bulk-completion strings
  (`qazaCompleteCount`, `qazaCompletedCount`).
- Settings now offers a real English/اردو choice; the "Urdu is not available
  yet" placeholder is gone.

Translated surfaces: navigation, Home, the Qaza workspace (filters, states,
errors, row semantics), Add Qaza (all three steps), the calendar picker,
the Calculator's step scaffolding and preflight dialog, Settings
appearance/language, notifications (including the scheduled reminder itself),
the Knowledge Base, the completion screen, History/Logs, Account, Data & Cloud,
and the welcome/splash screens.

Calendar weekday headers come from `MaterialLocalizations.narrowWeekdays`
rather than a hardcoded English list, re-indexed to preserve the Monday-first
grid.

Strings that interpolate a value use placeholders rather than concatenation —
`{prayer} Qaza`, `Original Qaza date: {date}` — so word order and possessives
can differ per language instead of being fixed by Dart string building.

Test hosts use `test/support/test_app.dart`, which configures the same
delegates production does. A screen rendered without them throws, which is the
correct behaviour and is why the helper exists rather than a silent English
fallback.

### Startup and authentication (plan §21, §22)

The journey is now `Splash → Google authentication → Home`. The blocking
first-time setup is gone: no per-UID `setup_complete` flag, no
`FirstTimeSetupScreen`, and `AuthGate` is down from six `setState` calls to two.
Theme (System) and language (English) are persisted defaults changed from
Settings, so a newly signed-in account — including a brand new one — lands on
Home immediately. Signing out returns to the welcome entry.

### Cloud bootstrap and hydration (plan §27)

`SyncStatus` gained `bootstrapping` and `hydrating`, and `SyncState.isReady`
distinguishes them from every working state. `OfflineFirstQazaRepository` runs
`BOOTSTRAPPING → (local empty?) → HYDRATING → READY` on each `setActiveUser`,
and `ensureHydrated()` gates every read path. Availability and duplicate
calculations therefore cannot observe a partially hydrated ledger on a fresh
device or reinstall. Offline starts, empty cloud accounts, failed and
interrupted pulls, and account switches all terminate in a ready state. See
`docs/OFFLINE_FIRST_ARCHITECTURE.md`.

### Knowledge Base (plan §29)

Audited against every requirement in §29. The pipeline is compliant as it
stands: `assets/knowledge_base/content/articles.json` → `KnowledgeBaseParser` →
domain models → repository → Riverpod → UI, with schema-version checking,
kebab-case id/slug validation, category validation, required bilingual
`{en, ur}` text for title/summary/body, structured references
(`source`/`citation`/`url`), unique tags, search, category filtering, a lazy
`SliverList.builder`, semantic labels, and no article text hardcoded in any
widget. No Qaza import appears anywhere under `features/knowledge_base/`, so it
stays isolated from Qaza business logic.

Two changes: the module's chrome is now localized (titles, search hint,
category labels, empty/error states, references and related-articles headings),
and the five stray `*_test.dart` files that shipped inside `lib/` moved to
`test/knowledge_base/`.

**Outstanding, and a content decision rather than an engineering one:**
`articles.json` currently contains `"articles": []` — the Knowledge Base ships
with no content. The pipeline and its validation are ready for it, but the
Masail and Mugalat articles need to be authored and scholar-reviewed (see
`docs/KNOWLEDGE_BASE_RELEASE_CHECKLIST.md`). That is deliberately not something
this implementation invented.

### Notifications (plan §28)

There is still exactly one scheduler and one recurring reminder. What changed:
the pending-Qaza gate reads the database aggregate instead of the full ledger,
and **notification text is localized**. `NotificationContent` carries title,
body, channel name and channel description into the platform layer, resolved by
`NotificationSettingsNotifier` from the active locale through
`lookupAppLocalizations` — the scheduler has no widget tree and now builds no
user-facing strings of its own. Covered by 19 tests including permission
revocation, restart reconciliation, per-account isolation, the pending →
no-pending transition, and reminder/test text following the chosen language.

### Documentation (plan §39)

`PROJECT_STATUS.md` is the single canonical status document. `docs/README.md`
indexes the canonical architecture documents, and 19 point-in-time
`TASK*_STATUS.md` / `KNOWLEDGE_BASE_PART_*_STATUS.md` records moved to
`docs/archive/` with a note that the canonical documents win wherever they
disagree. `docs/ARCHITECTURE.md` — named by the plan but previously missing —
now exists.

### Regression matrices (plan §40, §34)

`test/sync_regression_matrix_test.dart` covers the sync rows that were not
already pinned elsewhere: offline reporting, an offline write held locally and
flushed on reconnect, sign-out clearing the active user, sign-in restoring the
persisted ledger, and cross-account isolation. Upload, pull, conflict handling
and multi-device convergence remain in `task3h_offline_first_repository_test`;
bootstrap in `cloud_bootstrap_test`.

`test/accessibility_matrix_test.dart` covers semantic labels (date + prayer +
status in one announcement), semantics following the active locale, 48dp touch
targets, 1.3x and 2.0x text scaling, and disabled states.

The text-scaling row found a real defect: at 2.0x every ledger row overflowed
by 16px, because `ListTile` constrains its trailing slot to the tile height and
the row stacked prayer name over status there. Status moved into the subtitle
and the tile is now three-line; the semantics label was already carrying both,
so screen-reader output is unchanged.

### Performance at scale (plan §30, §38, §41)

`test/large_dataset_ux_regression_test.dart` drives the real V2 UX paths against
ledgers of **1,000 / 5,000 / 10,000 records** through a counting repository, and
asserts per size that:

- the Qaza workspace pages in bounded chunks and never calls the full-ledger API;
- prayer, status and date filtering happen in the data source, not in Dart;
- Home progress comes from the database aggregate;
- completion uses a single bounded oldest-pending lookup;
- availability stays scoped to the requested dates and prayers;
- the calculator preflight — a 365-day, six-prayer estimate — does not
  materialize the ledger;
- bulk selection stays bounded to the loaded page.

Startup is bounded too: the bootstrap probes local emptiness with a
single-record page rather than loading the snapshot, so signing in with 10,000
records costs one bounded query.

### Theme (plan §22)

The theme mode is persisted locally and restored on startup, defaulting to
System. Colour, type, shape and elevation tokens come from the Stitch "Serene
Sanctuary" export in `lib/core/theme/app_theme.dart`.

## Known gaps

- **Localization is not yet complete across every screen.** A sweep for English
  literals across `lib/features` still finds roughly **86**, concentrated in
  `authentication_screen.dart`, the body of `calculator_screen.dart` (only its
  step scaffolding and preflight dialog were converted), the Settings section
  rows below Appearance/Language, `notifications_screen.dart`, and a few
  `core/widgets` defaults. Each is a matter of adding ARB keys — no further
  structural work — but the count is larger than a screen-by-screen tally
  suggests, because a screen can be partly converted.
- **Hijri month names are still English.** `DateFormatters.hijriLabel` uses the
  `hijri` package's month names; only the surrounding format is localizable.
- **Noto Serif and Manrope font files are not bundled.** `pubspec.yaml` has no
  `fonts:` section, so the Serene Sanctuary type scale renders in the platform
  default family.
- **Cloud bootstrap/hydration states** (`BOOTSTRAPPING / HYDRATING / READY`) do
  not exist yet.
- `docs/` still holds point-in-time `TASK*_STATUS.md` and
  `KNOWLEDGE_BASE_PART_*_STATUS.md` files awaiting consolidation.
- `dart format --set-exit-if-changed` (plan §47) currently fails on roughly 60
  files that were never format-clean. Formatting them is a deliberate,
  separate change rather than incidental churn inside feature work.

## CI gate (plan §47)

Run locally against the working tree:

| Step | Result |
| --- | --- |
| `flutter pub get` | Pass |
| `flutter analyze` | Pass — 0 errors, 0 warnings, 96 info-level lints |
| `dart format --set-exit-if-changed lib test` | **Pass** — exit 0 |
| `dart run build_runner build` (Drift) | Pass — 0 outputs written, no generated drift |
| `flutter test` | Pass — 372/372 |
| `flutter build apk --debug` | **Not run** — see below |
| `flutter build apk --release` | **Not run** — see below |
| GitHub Actions | **Not verified** — nothing pushed |

The format check passes for the first time as of commit
`Apply dart format to the pre-existing baseline`, which reformatted the 41
files that predate this work and were never format-clean. It is formatting
only and touches no file the V2 feature work changes.

### Android builds

Gradle fails before compiling with
`java.io.IOException: Unable to establish loopback connection`, with and
without the Gradle daemon. That is the local sandbox refusing localhost
sockets, not a defect in the project: no Dart or Gradle source is reached.
`.github/workflows/flutter-ci.yml` already has a `build_android` job running
both `flutter build apk --debug` and `--release`, so pushing the branch is the
way to get a real result.

### Release signing

`android/key.properties` does not exist and `android/app/build.gradle` still
carries `signingConfig = signingConfigs.debug` under a
`// TODO: Add your own release signing config.` A release build therefore
produces an APK signed with the **debug** key: it compiles, but it is not a
shippable artifact. Supplying a keystore is a release decision, not an
implementation one.

## Verification

Local run at the time of writing: **311 tests passing**, `flutter analyze` clean
of errors and warnings (remaining findings are pre-existing `info` lints).
Step 21 — the full CI gate including Android debug and release builds — has not
been run, so completion is not claimed.

## Pre-V2 history

The SharedPreferences → Drift/SQLite migration (Parts 1–12) and the Task 7–11
reconciliation stream are complete; their detail lives in `docs/`. Migration
Part 13 and reconciliation Tasks 12–13 are superseded by V2 step 21, the single
remaining CI/build gate.

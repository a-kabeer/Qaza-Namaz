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

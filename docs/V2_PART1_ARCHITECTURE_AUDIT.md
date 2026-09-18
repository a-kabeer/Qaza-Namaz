# V2 Part 1 — Repository and Architecture Baseline Audit

Audit of `main` (commit `8e05946`, plus the uncommitted Add Qaza 3-step flow and
Serene Sanctuary theme work) against the V2 Master Plan, section 4.

This is step 1 of the plan's 21-step implementation order. It changes no
production code; it establishes the canonical dependency map and the concrete
defect list that steps 2–21 work against.

---

## 1. Canonical dependency map

The target boundary from the plan is already the real boundary for Qaza data.
No widget imports `data/local/**`, `data/repositories/**` or any Drift symbol —
verified by import sweep across `lib/features/` and `lib/core/`.

```text
Widgets (lib/features/**, lib/core/widgets/**)
  │  watch / read only providers declared in lib/app/providers.dart
  ▼
Riverpod (lib/app/providers.dart + feature controllers)
  │  CalendarController · AddQazaFlowController · HistoryLogsNotifier
  │  NotificationSettingsNotifier · QazaRecordsNotifier · ThemeModeNotifier
  ▼
QazaService (lib/domain/services/qaza_service.dart)
  │  composes QazaAvailabilityService (pure domain rules)
  ▼
QazaRepository (lib/domain/repositories/qaza_repository.dart)
  │  OfflineFirstQazaRepository ── remote ──▶ FirestoreQazaRepository
  ▼  (local)
QazaLocalStore ──▶ DriftQazaLocalStore
  ▼
QazaRecordsDao · SyncOutboxDao
  ▼
AppDatabase (Drift / SQLite)
```

Composition root: `lib/main.dart` → `QazaNamazApp` (`lib/app/app.dart`) →
`AuthGate` → `WorkspaceShell`. Every dependency is constructed in
`lib/app/providers.dart`; no feature constructs a repository, DAO or database.

### Intentionally isolated infrastructure

These bypass `QazaService` by design and are **not** violations:

| Path | Why isolated |
| --- | --- |
| `data/migration/shared_preferences_to_drift_migrator.dart`, `qaza_database_bootstrap.dart` | one-shot legacy import; runs below the service boundary |
| `features/auth/auth_gate.dart` (SharedPreferences) | per-UID first-run flag, not ledger data |
| `features/calculator/calculator_persistence.dart` (SharedPreferences) | calculator *inputs*, not Qaza records |
| `features/notifications/notification_controller.dart` (SharedPreferences) | reminder settings, not Qaza records |
| `features/knowledge_base/**` | self-contained content pipeline, no Qaza business logic |

---

## 2. Findings against the section 4 checklist

| # | Checklist item | Verdict |
| --- | --- | --- |
| 1 | duplicate providers | **Clean** — one composition root, no duplicates |
| 2 | duplicate services | **Clean** — one `QazaService`, one `QazaAvailabilityService` |
| 3 | duplicate repositories | **Clean** — one interface, three intentional implementations (offline-first façade, Firestore remote, Drift local store) |
| 4 | direct DAO access from widgets | **Clean** — zero occurrences |
| 5 | direct database access from widgets | **Clean** — zero occurrences |
| 6 | business logic inside screens | **Defect — D1** |
| 7 | legacy full-ledger providers | **Defect — D2** |
| 8 | obsolete dashboard implementation | **Defect — D3** |
| 9 | duplicate calendar logic | **Clean** — one `CalendarController` + one `CalendarPicker` |
| 10 | duplicate date conversion logic | **Partial — D4** |
| 11 | duplicate Qaza conflict logic | **Defect — D5** |
| 12 | old SharedPreferences production paths | **Clean for the ledger** — remaining uses are settings/migration (table above) |
| 13 | redundant navigation paths | **Defect — D6** |
| 14 | stale status documentation | **Defect — D7** |

---

## 3. Defect list

### D1 — Workflow state still owned by widgets

`lib/features/calculator/calculator_screen.dart` is 554 lines with **22
`setState` calls** and owns step position, validation, the calculation result,
restore-from-persistence and the tracker-insert lifecycle. It is the single
largest boundary violation left in the app.

`setState` inventory (feature layer):

| File | Calls | Assessment |
| --- | --- | --- |
| `calculator/calculator_screen.dart` | 22 | workflow state — needs `CalculatorController` (plan §5) |
| `qaza/pending_dates_screen.dart` | 8 | bulk-selection + completion state — needs `QazaTrackerController` (plan §5, §16) |
| `settings/notifications_screen.dart` | 6 | mostly form-local; controller already exists for the domain part |
| `auth/auth_gate.dart` | 6 | startup/setup lifecycle — touched by plan §21–22 |
| `qaza/add_qaza_screen.dart` | 4 | acceptable — domain state already moved to `AddQazaFlowController` |
| remaining files | ≤ 4 each | presentation-local; allowed by plan §5 |

Controllers required by plan §5 versus what exists:

| Required | Status |
| --- | --- |
| `AddQazaController` | **Exists** as `AddQazaFlowController` (uncommitted) |
| `CalculatorController` | **Missing** |
| `QazaTrackerController` | **Missing** (no tracker screen yet — see D6) |
| `HistoryController` | **Exists** as `HistoryLogsNotifier` |

### D2 — Legacy full-ledger providers: four are already dead, two are live

`lib/app/providers.dart` declares six full-ledger paths. Consumer sweep across
`lib/` and `test/`:

| Provider | Production consumers | Action |
| --- | --- | --- |
| `loadedRecordsProvider` | **none** | delete |
| `overallProgressProvider` | **none** | delete |
| `prayerProgressProvider` | **none** | delete |
| `qazaHistoryProvider` | **none** | delete |
| `pendingForPrayerProvider` | **none** | delete |
| `qazaRecordsProvider` | `data_management/qaza_data_management_screen.dart:53` (refresh only), `notifications/notification_controller.dart:90,98` | migrate, then delete |

Five of the six can be deleted with no migration work at all. The live one
matters: `notification_controller.dart:98` calls
`ref.read(qazaRecordsProvider.future)` purely to decide whether any pending Qaza
exists — a **full-ledger read to answer a boolean**, and a direct violation of
plan §30 ("no completion full-ledger reads" / aggregate-first). It should read
`progressSummaryProvider` instead.

### D3 — Dashboard duplication is already dead code

`lib/features/dashboard/dashboard_screen.dart` (169 lines) has **zero production
consumers**. The only reference in the repository is
`test/dashboard_progress_test.dart`. `WorkspaceShell` routes to `HomeScreen`.

Plan §20 is therefore a deletion, not a migration: remove the screen, remove or
re-point the test. No consumer migration is required.

### D4 — Prayer labels duplicated; date utilities are clean

Date handling is single-sourced and correct: `QazaDate` (normalize / key /
parseKey / fromRecordId) is the only date-identity path, `DateFormatters` is
presentation-only, and `package:hijri` is imported in exactly one file
(`features/calendar/calendar_picker.dart`), keeping Hijri derived.

Prayer *labels* are not single-sourced. `PrayerTypeX.label` exists in
`core/constants/prayer_types.dart`, but the same switch is re-implemented in:

- `features/home/home_screen.dart:101` (`_label`)
- `features/calculator/calculator_screen.dart:471`
- `core/widgets/prayer_card.dart:69` (label + rakaat metadata combined)

This is minor today but blocks plan §23: localized prayer names need one
lookup point, not four.

### D5 — One availability engine, but the preflight contract is incomplete

`QazaAvailabilityService` is correctly the single conflict engine — identity is
`userId + normalized Gregorian date + prayerType` everywhere, and
`QazaService.recordQazaForDates` re-runs the same analysis at save time before
delegating to the repository's `insertOrIgnore` + unique key. There is **no
second duplicate-checking algorithm** anywhere in the app.

Two real gaps against plan §6 and §14:

1. **`alreadyCompleted` is not actually derived.** `QazaAvailabilityAnalysis`
   exposes `alreadyPrayed`, but it is populated only from the `prayedKeys`
   parameter, which every production caller leaves empty. A *completed* record
   is counted as `alreadyRecorded`. The plan requires
   `alreadyRecordedCount` and `alreadyCompletedCount` to be distinguishable —
   today they collapse into one number. The data to fix this is already loaded:
   `_getExistingForAvailability` fetches records with their `status`.
2. **The calculator does not run the preflight at all.**
   `calculator_screen.dart:246 _addToTracker()` shows a confirmation dialog
   built from `trackerRecordCount(calculation)` — a raw
   `totalDays × prayerCount` multiplication — then calls `recordQazaForDates`.
   The user is shown the *calculated* count, never "Already Recorded" /
   "Already Completed" / "New to Add". The insert itself is still safe (the
   service re-analyses and the DB constraint is final), so this is a
   **disclosure defect, not a data-integrity defect**.

Missing fields on the shared preflight model: `blockedDateCount`,
`existingCandidates`, and a real `alreadyCompletedCount`.

### D6 — Navigation does not match the target destination set

| | Destination 1 | 2 | 3 | 4 |
| --- | --- | --- | --- | --- |
| **Target (plan §3)** | Home | **Qaza** | Calculator | Settings |
| **Current shell** | Home | Calculator | **Logs** | Settings |

There is no Qaza tracker destination. The canonical Qaza workspace described in
plan §16 does not exist; its function is currently spread across a nested chain
reached from Home:

```text
Home ──▶ "View All Qaza" ──▶ NamazWiseScreen ──▶ PendingDatesScreen(prayer)
Home ──▶ "<Prayer> — N pending" ─────────────────▶ PendingDatesScreen(prayer)
```

`NamazWiseScreen` (33 lines) is a pure prayer-picker with no state of its own —
exactly the "unnecessary screen" the plan's objective asks to remove. Its two
entry points from Home already duplicate each other.

Shell mechanics themselves are sound and should be preserved: `IndexedStack`
with lazy mounting, reselect-is-a-no-op (`workspace_shell.dart:28`), and
`PopScope` returning non-root tabs to Home (`:35`).

### D7 — Documentation and stray test files

- `PROJECT_STATUS.md` is written entirely around the *previous* reconciliation
  stream (Tasks 7–13, migration Parts 1–13). It has no V2 section. Plan §39
  requires one canonical status document.
- `docs/` holds 12 `TASK*_STATUS.md` / `KNOWLEDGE_BASE_PART_*_STATUS.md`
  point-in-time files that plan §39 wants consolidated.
- `ARCHITECTURE.md` is listed in plan §39 as a file to update but **does not
  exist**; the nearest equivalents are `DATABASE_ARCHITECTURE.md` and
  `OFFLINE_FIRST_ARCHITECTURE.md`.
- Four `*_test.dart` files live under `lib/`, not `test/`:
  `features/knowledge_base/presentation/knowledge_base_providers_test.dart`,
  `knowledge_base_accessibility_test.dart`,
  `knowledge_article_detail_page_test.dart`,
  `features/knowledge_base/data/bundled_knowledge_base_repository_test.dart`,
  `knowledge_base_parser_test.dart`. They ship in the production tree and are
  not picked up by `flutter test`.

---

## 4. Not-yet-started V2 areas (no existing implementation to audit)

| Plan section | Current state |
| --- | --- |
| §23 Localization | **Absent.** `MaterialApp` in `app/app.dart` declares no `locale`, `localizationsDelegates` or `supportedLocales`. No ARB files, no `flutter_localizations` dependency in `pubspec.yaml`. All strings are inline English literals. |
| §24 RTL/LTR | **Absent**, follows from the above. |
| §25 Theme persistence | **Absent.** `ThemeModeNotifier` (`providers.dart:118`) holds `AppThemeMode` in memory only; there is no read/write to storage, so the choice is lost on restart. |
| §27 Cloud bootstrap/hydration | **Partial.** `qaza_database_bootstrap.dart` exists for the SharedPreferences→Drift path; there is no `BOOTSTRAPPING / HYDRATING / READY` startup state for a remote-data/empty-local device. |
| §33 Batch/source metadata | **Absent by design.** `QazaRecord` has no `creationSource` or `batchId`. Plan §33 explicitly allows documenting this as a future-compatible decision instead of implementing it. |

Also unbundled: **Noto Serif and Manrope font files are not in the repository.**
`pubspec.yaml` has no `fonts:` section and `assets/` contains no font binaries,
so the Serene Sanctuary type scale currently renders in the platform default
family. This blocks plan §44's UI-consistency sign-off.

---

## 5. What this means for the implementation order

The audit changes the expected cost of several steps:

**Cheaper than the plan assumes**
- Step 9 (Dashboard Removal) — pure deletion, no consumers (D3).
- Step 17 (Legacy Provider Cleanup) — five of six providers are already dead (D2).
- Step 3 (Shared Preflight) — the engine exists and is genuinely single-sourced;
  the work is extending the result model and wiring the calculator, not building
  an engine (D5).
- Step 4/5 (Add Qaza UX) — already implemented in the uncommitted working tree
  and passing; needs verification against §7–§10, not reimplementation.

**More expensive than the plan assumes**
- Step 11 (Localization) — greenfield, and it depends on D4 (prayer labels) and
  on every inline string literal in ~20 screens.
- Step 7 (Qaza Tracker UX) — the destination does not exist at all (D6); this is
  a new screen plus a new controller, not a consolidation.
- Step 6 (Calculator Reconciliation) — 554 lines and 22 `setState` calls to move
  behind a controller (D1) *and* the preflight display to add (D5).

**Blocked on assets, not code**
- Font binaries must be added before §44 can pass.

---

## 6. Verification

- Import-boundary sweep: `grep -rn "import.*data/local\|import.*data/repositories\|import.*database" lib/features lib/core` → 0 results.
- Provider-consumer sweep across `lib/` and `test/` for all six full-ledger providers.
- `package:hijri` import sweep → 1 result.
- `setState(` counts per feature file.
- Full suite at time of audit: **267 tests passing**; `flutter analyze` clean on
  touched files.
- No production code was modified by this audit.

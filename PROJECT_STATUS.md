# Qaza Namaz App — Project Status

## Current Task
Task 3G — Calendar Engine, Gregorian/Hijri Support & Calendar UX

## Overall Progress
Task 1 and Task 2 remain complete and previously runtime-verified. Task 3 is being rebuilt incrementally from the supplied Stitch ZIP. Tasks 3A–3F are implemented. Task 3G adds the production calendar layer: a centralized Gregorian/Hijri (Umm al-Qura) calendar engine, a reusable calendar picker with single/range selection and future-date protection, and full Add Qaza integration.

## Task Status
- Task 1: 🟢 COMPLETE & VERIFIED — Qaza ledger business workflow and tests are complete.
- Task 2: 🟢 COMPLETE & VERIFIED — Firebase Authentication, Google Sign-In, Firestore persistence, user-scoped rules, and Android runtime verification completed.
- Task 3: 🟡 PARTIAL — Stitch-derived UI rebuild is in progress by feature area.
- Task 3A: 🟡 IMPLEMENTED — Authentication & Onboarding implementation added; local/device verification pending.
- Task 3B: 🟡 IMPLEMENTED — Dashboard, global navigation, live ledger overview, and system states added; local/device verification pending.
- Task 3C: 🟡 IMPLEMENTED — Add Qaza setup, single-date/range selection, missed-prayer selection, duplicate-safe review, confirmation, and record creation flow added; local/device verification pending.
- Task 3D: 🟡 IMPLEMENTED — Complete oldest pending Qaza, Namaz-wise prayer selection, pending-date multi-select completion, timestamp/original-date preservation, and Witr independence implemented; local/device verification pending.
- Task 3E: 🟡 IMPLEMENTED — Logs/history, overall progress, per-prayer progress, completed-record ordering, original-date display, refresh, and empty/error states added; local/device verification pending.
- Task 3F: 🟡 IMPLEMENTED & TEST-VERIFIED — Centralized theme (System/Light/Dark), reusable UI component library, completed Settings and Account screens, guarded sign-out, and legacy UI removal completed; physical Android device verification still pending.
- Task 3G: 🟢 IMPLEMENTED & TEST-VERIFIED — Production calendar engine (Gregorian + Hijri Umm al-Qura), calendar switching, single/range selection, past-date navigation, today handling, future-date protection, date normalization, and Add Qaza integration completed. `flutter analyze` clean and `flutter test` passing (87 tests) in the implementation environment; Android debug APK builds successfully; interactive physical-device run not possible in this environment (no Android device/emulator attached).
- Task 4: 🔴 NOT STARTED
- Task 5: 🔴 NOT STARTED
- Task 6: 🔴 NOT STARTED
- Task 7: 🟡 PARTIALLY COMPLETE — core business logic implemented as part of Task 1.
- Task 8: 🔴 NOT STARTED
- Task 9: 🔴 NOT STARTED
- Task 10: 🔴 NOT STARTED
- Task 11: 🔴 NOT STARTED
- Task 12: 🔴 NOT STARTED
- Task 13: 🔴 NOT STARTED
- Task 14: 🟡 PARTIALLY COMPLETE — core unit/widget tests exist; broader QA not started.
- Task 15: 🔴 NOT STARTED

## Task 3E Scope
The supplied Stitch design uses Dashboard, Calculator, Logs, and Settings as the primary navigation. Its dashboard includes an overview of remaining/completed prayers, a progress ring, and recent ledger entries with preserved original missed dates and completion times. The implementation treats those values as derived from real Qaza records instead of Stitch demo numbers.

## Task 3E Implementation
- Added `lib/features/ui/history_progress_v2.dart` as the active Logs/Progress screen.
- Uses `QazaService.history()` for completed history rather than maintaining a separate activity ledger.
- Uses `QazaService.overallProgress()` for overall pending/completed progress and `QazaService.prayerProgress()` for each of the six independent prayer categories.
- Completed history is displayed newest-completion-first while preserving the original missed-prayer date separately from the completion timestamp.
- Witr is displayed independently from Isha because progress is calculated by the individual `PrayerType` values.
- Added explicit loading, retryable error, pull-to-refresh, and empty-history states.
- Replaced the active V2 Workspace Logs destination so the old placeholder/legacy history view is no longer the active Logs route.
- Added `test/task3e_history_progress_test.dart` covering derived progress, all six prayers, completed-history ordering, exclusion of pending records, preservation of original dates, and the empty state.

## Task 3F Implementation
- `lib/core/theme/app_theme.dart` is the single source of truth: Stitch palette constants (dark base #091515, primary #84D4D3, interactive #0D6E6E, amber #FFB77D, mint #4FDBCC, dark surfaces #121E1E/#162222/#202C2C/#2B3737, light base #F8FAF9, light surfaces #F0F4F2/#E2EAE6/white) mapped onto Material 3 `ColorScheme` roles, with centralized typography, button, input, card, navigation, dialog, chip, snackbar, divider and progress-indicator themes in one `_base` builder used by both `AppTheme.light()` and `AppTheme.dark()`.
- `QazaNamazApp` owns `themeMode` and rebuilds the whole `MaterialApp` when it changes; the mode flows `AuthGate → WorkspaceShellV2 → SettingsScreen`, so a Settings change re-themes every screen (auth, onboarding, dashboard, flows, logs, settings, account, dialogs).
- Rebuilt `lib/features/ui/components.dart` as the reusable library: `AppSpacing`, `PageScaffold`, `SectionHeading`, `PrimaryButton`, `SecondaryButton`, `IconActionButton`, `StatusChip`, `Metric`, `LoadingState`, `ErrorState`, `EmptyState`, `SettingsSection`, `SettingsNavRow`, `confirmDestructive`, `DestructiveActionRow`, `AccountSection`, and shared `formatDate`/`formatDateTime` helpers.
- Settings screen now contains Appearance (System/Light/Dark segmented control that changes the whole app immediately), Language (English active; Urdu explicitly marked as pending — no fake localization), and General rows for Account, Prayer & Fiqh Rules, Notifications, Data & Cloud, and About. No Privacy/Terms links because no destination content exists yet.
- Account screen renders the real Firebase user (display name, email, photo when available) with sign-in method and account status, a developer-context Firebase UID section, and a destructive-confirmation-guarded sign-out. No fake phone/WhatsApp/email auth — those buttons remain on the auth screen as explicit "not connected yet" notices only.
- Sign-out goes through `AuthGate`'s `authStateChanges` stream; after sign-out the user returns to the welcome/authentication entry point and stale local UI is not restored because the shell is rebuilt from the auth stream. Firestore records are never touched during sign-out.
- Removed the legacy UI implementations (`FinalAuthPage`, `FinalAppShell`, legacy `DashboardScreen`, `AddQazaScreen`, `CompleteQazaScreen`, `NamazWiseScreen`, `PendingDatesScreen`, `CalculatorScreen` duplicate, legacy `HistoryScreen`, `ProgressScreen`) so `final_ui.dart` only hosts the active Settings, Account, Fiqh, Notifications, Data & Cloud, and About screens.
- Added `test/task3f_theme_settings_account_test.dart` covering Stitch palette derivation, light/dark propagation, system-brightness following, Settings theme switching propagating globally, Settings navigation, Account rendering, confirmation-guarded sign-out that never deletes Qaza data, and empty/loading/error states.

## Task 3G Calendar Implementation

### Conversion method (documented, centralized)
- Hijri conversion uses the **Umm al-Qura** tabular calendar via the pure-Dart `hijri` package (`^3.0.1`), wrapped behind the project's own `IslamicCalendar` abstraction (`lib/domain/calendar/islamic_calendar.dart` + `hijri_ummalqura_calendar.dart`).
- **There is no universally agreed Hijri method.** The selected basis is the Umm al-Qura lookup table (Kingdom of Saudi Arabia civil calendar), **not** observational or local moon-sighting calculations. Local sightings can differ by ±1 day; users relying on observational calendars may see an off-by-one day around month boundaries.
- **Timezone assumption:** conversions operate on calendar dates (year/month/day), not instants; the app stores normalized local dates and performs no timezone shifting during conversion.
- **Supported range:** 1 Muharram 1356 AH (14 Mar 1937) through 30 Dhu Al-Hijjah 1500 AH (16 Nov 2077). Conversions outside this window throw `RangeError`, and the picker clamps navigation to the window. The picker's selectable floor is 1 Jan 1950 (`CalendarEngine.minimumDate`), which is fully inside the table.
- **Centralization:** all conversion lives in `lib/domain/calendar/` (`CalendarEngine`, `HijriDate`, `IslamicCalendar`, `HijriUmmAlQuraCalendar`, `CalendarLabels`). No widget performs its own Hijri math; switching the conversion method later only requires swapping the `IslamicCalendar` implementation.

### Calendar engine API
- `gregorianToHijri` / `hijriToGregorian`, `currentGregorian` / `currentHijri` (injectable `now` clock for tests), `normalize`, `isSameDay`, `isFuture`, `isBeforeMinimum`, `dateKey`, `expandRange`, and month arithmetic on `HijriDate` (`addMonths`, `monthIndex`, `compareTo`, equality).

### Picker UX (`lib/features/calendar/calendar_picker_v2.dart`)
- Calendar mode banner (Gregorian / "Hijri calendar (Umm al-Qura)") makes the active mode obvious.
- Single-date and range modes; ranges show a "Tap a later date to finish the range" prompt and a selected summary (`calendar_selected_summary` key) with day count.
- Every selection shows the real converted alternate-calendar date (e.g. `10 Sep 2026` + corresponding Hijri date), never demo dates.
- Future days render locked (no `InkWell`, no tap handler) and month navigation is disabled past today's month and before 1950.

### Add Qaza integration (`lib/features/qaza/qaza_add_flow_v2.dart`)
- The old "Hijri is reserved for the calendar engine task" gate is removed; Method → calendar mode (Gregorian/Hijri) → date mode (single/range) → calendar picker → missed prayers → review → save.
- Selections are normalized through `CalendarEngine.normalize` before every save; `QazaRecord.originalDate` remains the canonical **Gregorian** date — Hijri is display-only metadata, exactly as the data-integrity rules require.
- Range expansion flows through `QazaService.recordQazaForDates`, which de-duplicates by prayer+date and preserves Witr as a separate `PrayerType` from Isha.
- Step lists now carry distinct keys so scroll position resets between steps (fixes landing mid-list when advancing).

## Test Hardening After User Run
The user's local `flutter test` exposed a deterministic test-design issue rather than a confirmed product-logic failure: Flutter's `ListView` lazily builds off-screen children, so assertions against lower prayer/history items were made before those widgets existed in the test tree. One assertion also expected a literal `2 completed` string that the UI does not render; the UI intentionally renders per-prayer values such as `0 pending • 1 completed` and separate overall metrics.

The tests were hardened by using a larger deterministic test viewport (`800x1600`, DPR 1) for the affected Workspace and Task 3E widget tests. This makes the complete fixture visible without relying on fragile scroll/finder interaction. The Task 3E progress assertion now checks the actual rendered per-prayer strings. The Workspace Logs assertion now targets the active `Logs & Progress` screen and its actual empty-state text.

## Verification
- Task 2 Firebase runtime verification: 🟢 VERIFIED by user on physical Android device in earlier Task 2 work.
- Task 3 ZIP audit: 🟢 COMPLETED.
- Task 3A–3E implementations: 🟢 COMPLETED (3E test hardening commits `4ed2d5363deb075b7cbc3fc7967e42d1c9a9af92`, `cb6653e2e871ebe34fc09dfe5741d586a62aa903`).
- Task 3F implementation: 🟢 COMPLETED with local verification in the implementation environment.
- Task 3F `flutter analyze`: 🟢 PASSING — "No issues found!" across the whole project after the Task 3F refactor.
- Task 3F `flutter test`: 🟢 PASSING — 40 tests across 7 files (task1 ledger, add-flow, completion-flow, history/progress, workspace, auth-entry, and the new Task 3F theme/settings/account suite).
- Task 3F physical Android UI verification: NOT VERIFIED — device verification of theme switching, Settings, Account, and real Google sign-out remains pending.
- Task 3G implementation: 🟢 COMPLETED with local verification in the implementation environment.
- Task 3G `flutter pub get`: 🟢 PASSING (adds `hijri ^3.0.1`; no unrelated dependency upgrades).
- Task 3G `flutter analyze`: 🟢 PASSING — "No issues found!" across the whole project.
- Task 3G `flutter test`: 🟢 PASSING — 87 tests across 11 files, including the new `calendar_engine_test.dart` (unit/edge-case engine suite), `calendar_picker_test.dart` (picker widget suite), and `task3g_add_flow_calendar_test.dart` (Add Qaza x calendar end-to-end suite).
- Task 3G targeted calendar tests re-run after the full suite: 🟢 PASSING — 47 calendar-related tests across the three calendar files.
- Task 3G Android build: 🟢 `flutter build apk --debug` completes successfully (`build/app/outputs/flutter-apk/app-debug.apk`).
- Task 3G physical Android device verification: NOT VERIFIED — no Android device or emulator was attached to the implementation environment (only Windows desktop and web browsers); interactive picker/save/ledger-reopen verification on hardware remains for the user.
- GitHub Actions CI is configured to run Flutter analyze and test; the Task 3G commit should be observed on push.

## Task 3G Test Coverage Notes
- Engine unit tests cover: documented Umm al-Qura anchor dates, oldest/newest supported boundaries, out-of-range `RangeError`, Hijri month/year boundaries (29 Dhu Al-Hijjah → 1 Muharram), month lengths, leap-day Gregorian handling, round-trip Gregorian → Hijri → Gregorian across boundary dates, `expandRange` gap/duplicate guarantees, normalization, comparison, date-key stability, future/minimum validation, and delegation to an injected `IslamicCalendar` implementation.
- Picker widget tests use stable `ValueKey`s (`calendar_day_YYYY-MM-DD`, `calendar_prev_month`, `calendar_next_month`, `calendar_selection_prompt`, `calendar_selected_summary`), semantic text finders scoped where needed, and a fixed engine clock — no brittle positional finders.
- End-to-end tests drive the real Add Qaza flow with an in-memory repository and fixed clock, asserting at the domain level: pending `QazaRecord`s with canonical Gregorian `originalDate`, correct prayer types, exact range expansion (no gaps/duplicates), Witr separate from Isha, and that future-date taps never create records.

## Known Limitations
- Urdu localization is not implemented; the Language setting is intentionally marked as pending and does not translate the app.
- Notifications, cloud sync, export/import, and Privacy/Terms destinations do not exist yet; their Settings rows are honest placeholders that navigate to informational screens.
- Theme persistence across app restarts is in-memory (defaults to System on cold start); a persistence task has not been implemented yet.
- Physical Android verification of Tasks 3F and 3G was not possible in the implementation environment.
- Hijri conversion is tabular Umm al-Qura, not observational: dates may differ by ±1 day from local moon-sighting calendars, particularly at Hijri month boundaries. The conversion range is 1356–1500 AH; conversions outside throw `RangeError` by design and the picker clamps navigation to the supported window.
- Qaza records store only the canonical Gregorian `originalDate`; a selected Hijri date is converted before storage and is not persisted as separate calendar metadata. Re-displaying a record's Hijri date converts from the stored Gregorian date.

## Important Scope Boundary
This Task 3 rebuild uses the supplied Stitch ZIP as the UI/UX source of truth. Existing backend/domain functionality is preserved rather than replaced. Authentication methods beyond Google, OTP providers, email authentication, offline sync, export/import, notifications, and other dedicated infrastructure/business tasks remain separate until actually implemented. (Hijri/calendar calculation is now implemented by Task 3G.)

## Task 3F Sign-Off Notes
- Theme switching is global: `QazaNamazApp` owns the mode; Settings mutates it through the passed callback and every screen re-themes.
- Settings is active in the workspace navigation and Account is reachable from it; sign-out remains connected through `AuthGate`'s auth stream.
- No legacy screen became active; all legacy UI implementations were deleted.
- No data-deletion, counter-reset, record-fabrication, date-mutation, Witr-merging, or UID-isolation-bypassing behavior exists in Settings/Account paths; a dedicated test asserts records survive sign-out.

## Last Updated
2026-09-14 — Task 3G completed: production calendar engine (Gregorian + Hijri Umm al-Qura), calendar picker with single/range selection and future-date protection, full Add Qaza integration with canonical Gregorian storage; `flutter analyze` clean, 87 tests passing locally, Android debug APK builds.

## Next Task
Task 3H.


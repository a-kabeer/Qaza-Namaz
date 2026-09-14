# Qaza Namaz App — Project Status

## Current Task
Task 3F — Centralized Theme, Reusable UI, Settings & Account

## Overall Progress
Task 1 and Task 2 remain complete and previously runtime-verified. Task 3 is being rebuilt incrementally from the supplied Stitch ZIP. Tasks 3A–3E are implemented. Task 3F centralizes the app-wide theme and shared UI system, completes the Settings and Account experience on top of the real Firebase user, and wires global Light/Dark/System switching.

## Task Status
- Task 1: 🟢 COMPLETE & VERIFIED — Qaza ledger business workflow and tests are complete.
- Task 2: 🟢 COMPLETE & VERIFIED — Firebase Authentication, Google Sign-In, Firestore persistence, user-scoped rules, and Android runtime verification completed.
- Task 3: 🟡 PARTIAL — Stitch-derived UI rebuild is in progress by feature area.
- Task 3A: 🟡 IMPLEMENTED — Authentication & Onboarding implementation added; local/device verification pending.
- Task 3B: 🟡 IMPLEMENTED — Dashboard, global navigation, live ledger overview, and system states added; local/device verification pending.
- Task 3C: 🟡 IMPLEMENTED — Add Qaza setup, single-date/range selection, missed-prayer selection, duplicate-safe review, confirmation, and record creation flow added; local/device verification pending.
- Task 3D: 🟡 IMPLEMENTED — Complete oldest pending Qaza, Namaz-wise prayer selection, pending-date multi-select completion, timestamp/original-date preservation, and Witr independence implemented; local/device verification pending.
- Task 3E: 🟡 IMPLEMENTED — Logs/history, overall progress, per-prayer progress, completed-record ordering, original-date display, refresh, and empty/error states added; local/device verification pending.
- Task 3F: 🟡 IMPLEMENTED & TEST-VERIFIED — Centralized theme (System/Light/Dark), reusable UI component library, completed Settings and Account screens, guarded sign-out, and legacy UI removal completed. `flutter analyze` clean and `flutter test` passing (40 tests) in the implementation environment; physical Android device verification still pending.
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
- GitHub Actions CI is configured to run Flutter analyze and test; the Task 3F commit should be observed on push.

## Known Limitations
- Urdu localization is not implemented; the Language setting is intentionally marked as pending and does not translate the app.
- Notifications, cloud sync, export/import, Hijri calendar conversion, and Privacy/Terms destinations do not exist yet; their Settings rows are honest placeholders that navigate to informational screens.
- Theme persistence across app restarts is in-memory (defaults to System on cold start); a persistence task has not been implemented yet.
- Physical Android verification of Task 3F was not possible in the implementation environment.

## Important Scope Boundary
This Task 3 rebuild uses the supplied Stitch ZIP as the UI/UX source of truth. Existing backend/domain functionality is preserved rather than replaced. Authentication methods beyond Google, OTP providers, email authentication, offline sync, Hijri/calendar calculation, export/import, notifications, and other dedicated infrastructure/business tasks remain separate until actually implemented.

## Task 3F Sign-Off Notes
- Theme switching is global: `QazaNamazApp` owns the mode; Settings mutates it through the passed callback and every screen re-themes.
- Settings is active in the workspace navigation and Account is reachable from it; sign-out remains connected through `AuthGate`'s auth stream.
- No legacy screen became active; all legacy UI implementations were deleted.
- No data-deletion, counter-reset, record-fabrication, date-mutation, Witr-merging, or UID-isolation-bypassing behavior exists in Settings/Account paths; a dedicated test asserts records survive sign-out.

## Last Updated
2026-09-14 — Task 3F completed: centralized theme + reusable components + Settings/Account + guarded sign-out; legacy UI removed; `flutter analyze` clean and 40 tests passing locally.

## Next Task
Task 3G.


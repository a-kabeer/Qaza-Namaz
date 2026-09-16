# Notifications Settings UX + Implementation Status

## Task
Replace the current Notifications placeholder/minimal workflow with a simple, production-ready Settings → Notifications experience.

## Branch
`task-notifications-settings-ux`

## Overall Status
**In progress**

## Scope
- One Settings → Notifications screen; no unnecessary sub-pages.
- Daily Qaza Reminder switch.
- Native Material reminder-time picker.
- Clear notification permission/status states.
- Permission request workflow.
- One daily reminder only when pending Qaza exists.
- Disable/cancel workflow while preserving selected time.
- Send Test Notification action with clear feedback.
- Local persistence and restart restoration.
- Material 3, existing theme, light/dark support, responsive UX.
- Automated tests plus actual notification/scheduling verification.

## Parts

| Part | Area | Status |
|---|---|---|
| 1 | Audit & baseline | ✅ |
| 2 | Notification state model | ✅ |
| 3 | Production Notifications UI | ✅ |
| 4 | Enable workflow | ✅ |
| 5 | Disable workflow | ✅ |
| 6 | Pending-Qaza scheduling rule | ✅ |
| 7 | Reminder time workflow | ✅ |
| 8 | Test notification | ✅ |
| 9 | Persistence & restore | ✅ |
| 10 | Runtime reconciliation | ☐ |
| 11 | Theme & responsive UX | ☐ |
| 12 | Notification tests | ☐ |
| 13 | Integration & regression | ☐ |
| 14 | Final verification & completion | ☐ |

## Part 1 — Audit & Baseline ✅

### Existing implementation audited
- `NotificationsScreen` was a minimal two-card workflow with a daily switch, time picker, and static explanation.
- Reminder time remained tappable even when the reminder was OFF.
- No visible notification permission/status state was exposed to the user.
- No test-notification action was exposed.
- The existing scheduler already used a single recurring notification ID and cancelled before rescheduling, providing a good base for one-reminder behavior.
- Permission handling was Android-focused through `requestNotificationsPermission()` and did not expose a separate status/reconciliation model.
- Existing notification settings were persisted locally with SharedPreferences but were not UID-scoped.
- Existing scheduler had no pending-Qaza gate, so it could schedule even when the ledger was empty.
- Existing focused notification tests covered the original enable/disable/time/persistence behavior and were extended for the new workflow.

### Audit decisions
- Preserve the current local-notification architecture and extend it rather than replacing it.
- Keep Notifications as one Settings screen with inline permission/status, reminder control, time selection, and test action.
- Derive pending-Qaza state from the existing `qazaRecordsProvider` so scheduling remains tied to the real ledger.
- Reconcile OS permission and scheduled state when settings are loaded/resumed instead of trusting only persisted preferences.
- Keep the selected time when the reminder is disabled.
- Treat scheduling as a single daily reminder; test notification uses a separate one-shot notification ID.

### Baseline issue carried into implementation
The first full CI run showed one notification test expectation mismatch: the fake scheduler reported permission as granted during initial status loading, so the controller correctly skipped requesting permission. The test was updated to model the permission state expected by the enable-flow assertion.

## Part 2 — Notification State Model ✅

### State model implemented
- `NotificationPermissionStatus` represents `notRequested`, `granted`, `denied`, `unavailable`, and `restricted` states at the model level.
- `NotificationScheduleStatus` separates the user's reminder preference from the derived operational state: `disabled`, `permissionRequired`, `noPendingQaza`, or `scheduled`.
- Scheduling decisions are derived from enablement + permission + pending-Qaza state instead of treating `enabled` as proof that a reminder is actually scheduled.
- The selected reminder time remains part of the persisted configuration and is independent from whether the reminder is currently active.
- Permission status and pending-Qaza state remain runtime-derived, while the user preference and reminder time remain locally persisted.
- Re-enabling an already-enabled reminder reconciles the actual schedule instead of silently skipping reconciliation.

### Part 2 verification coverage
- Tests cover the default state and derived schedule state.
- Tests cover the permission-request path with a distinct initial permission-status simulation.
- Tests cover disabled, scheduled, no-pending, and denied/permission-required state transitions.

## Part 3 — Production Notifications UI ✅

- Notifications is a single Settings screen with no unnecessary sub-pages.
- The daily reminder switch, reminder time, permission state, derived reminder status, and test action are visible in one compact flow.
- Reminder time is disabled while the reminder is OFF.
- Permission actions are available for not-requested and denied states.
- UI copy is concise and explains when the recurring reminder is actually scheduled.
- Controls are guarded against duplicate taps while an asynchronous notification operation is running.
- Existing Material theme colors are used instead of custom hardcoded notification colors.
- Restricted permission state is explicitly rendered so the state model remains exhaustive and user-visible.

## Part 4 — Enable Workflow ✅

- Enabling checks the current OS notification permission before allowing the reminder to remain enabled.
- When permission is not already granted, the app requests notification permission and only proceeds when granted.
- Denied permission leaves the reminder disabled and exposes an actionable blocked state in Settings.
- Successful enable persists the user's preference and reconciles scheduling using the selected time and pending-Qaza state.
- Enabling with no pending Qaza keeps the preference enabled but does not create a recurring notification.
- Re-enabling an already enabled reminder still reconciles the actual schedule instead of creating duplicates.

## Part 5 — Disable Workflow ✅

- Turning the Daily Qaza reminder OFF always cancels the recurring daily notification.
- The user's selected reminder time is preserved when disabling; it is not reset to the default.
- The disabled state is persisted so restart does not silently re-enable the reminder.
- The derived schedule state becomes `disabled`, preventing accidental rescheduling while the preference is OFF.
- Focused test coverage changes the reminder time before disabling and verifies the exact selected time remains available afterward.

## Part 6 — Pending-Qaza Scheduling Rule ✅

### Scheduling behavior
- The recurring reminder is scheduled only when the user preference is enabled, notification permission is granted, and at least one `QazaStatus.pending` record exists.
- When pending Qaza does not exist, the recurring reminder is explicitly cancelled even if the preference remains enabled.
- When pending Qaza appears after the reminder is enabled, the schedule is created automatically from the existing Qaza records provider.
- When the last pending Qaza is completed/removed, the recurring reminder is cancelled automatically.
- The daily schedule remains a single notification ID; reconciliation replaces the existing daily schedule rather than creating additional reminders.

### Verification coverage
- Focused notification tests simulate ledger changes after enabling and verify both transitions: no pending → scheduled and pending → no pending/cancelled.
- The controller's derived `NotificationScheduleStatus` is asserted as `scheduled` and `noPendingQaza` during those transitions.
- The Settings screen exposes `No pending Qaza. No reminder is scheduled.` when the preference remains ON without pending work.

## Part 7 — Reminder Time Workflow ✅

- The Settings UI uses the native Material `showTimePicker` with the current saved time as the initial selection.
- The default reminder time is 8:00 PM when no saved time exists.
- Selecting a time automatically persists the hour/minute without requiring a separate Save button.
- When the reminder is enabled and pending Qaza exists, changing the time reconciles the schedule immediately with the new time.
- When the reminder is disabled, changing the saved time does not schedule a notification; the new time is preserved for the next enable.
- Invalid hour/minute values are rejected before persistence or scheduling.
- Focused coverage verifies rescheduling, disabled-state persistence, default formatting, and invalid-time validation.

## Part 8 — Test Notification ✅

- A dedicated one-shot Test Notification action is available on the same Settings screen.
- Test notifications are blocked until notification permission is granted.
- The test action delegates to the local notification service without enabling or changing the daily reminder preference.
- The test notification uses a separate notification ID from the recurring daily reminder, so sending a test cannot replace or duplicate the daily schedule.
- The UI reports a clear success or failure SnackBar after the test action.
- Focused tests verify the test action fires successfully, does not change recurring schedule calls, and is rejected when permission is unavailable.

## Part 9 — Persistence & Restore ✅

- Daily reminder enabled/disabled state is persisted per active account.
- Selected reminder hour/minute are persisted per active account and restored together with the preference.
- Notification permission state remains derived from the device rather than being treated as a user preference.
- Controller recreation restores the same account's saved configuration without resetting the selected time.
- A different account receives its own default notification configuration rather than inheriting another account's reminder setting.
- This prevents notification preferences from leaking across signed-in accounts while keeping the existing SharedPreferences-based architecture.
- Focused tests verify same-account restoration and cross-account isolation.

## Completion Criteria
The task must not be marked complete until:

- Permission behavior is verified for granted, denied, not-requested, and unavailable/restricted states.
- Enabling the reminder checks permission before scheduling.
- Disabling cancels the scheduled reminder while preserving the selected time.
- Only one daily reminder can exist.
- A daily reminder is scheduled only when pending Qaza exists.
- The reminder is cancelled when there is no pending Qaza.
- Time changes are persisted and rescheduled correctly when enabled.
- Test Notification works and never creates a recurring schedule.
- Configuration restores correctly after app restart.
- Light/dark and narrow layouts are verified.
- Focused notification tests pass.
- Full regression tests, analysis, and Android debug/release builds pass at the final integration checkpoint.
- Manual/runtime verification confirms actual notification scheduling and permission behavior on a supported Android environment.

## Working Rules
- Audit before changing architecture.
- Preserve existing architecture unless a real weakness is found.
- Keep the workflow single-screen and simple.
- Fix failures, then rerun the affected tests/builds.
- Do not run full CI for every small part; reserve full CI for the appropriate final integration checkpoint.

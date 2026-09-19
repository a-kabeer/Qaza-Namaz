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
| 10 | Runtime reconciliation | ✅ |
| 11 | Theme & responsive UX | ✅ |
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

## Part 2 — Notification State Model ✅

- `NotificationPermissionStatus` represents `notRequested`, `granted`, `denied`, `unavailable`, and `restricted`.
- `NotificationScheduleStatus` represents `disabled`, `permissionRequired`, `noPendingQaza`, and `scheduled`.
- Scheduling is derived from preference + permission + pending-Qaza state.
- Selected time is independent from the enabled state.
- Runtime status remains device/ledger-derived while user preferences remain persisted.

## Part 3 — Production Notifications UI ✅

- Single Settings screen with switch, time, permission, reminder status, and test action.
- Reminder time disabled while OFF.
- Permission actions exposed inline where applicable.
- Compact Material 3 layout using existing theme colors and asynchronous busy-state guards.
- Restricted permission state is rendered explicitly.

## Part 4 — Enable Workflow ✅

- Checks OS permission before enabling.
- Requests permission when needed and keeps the reminder OFF when denied.
- Persists successful enablement and reconciles the schedule.
- No schedule is created when there is no pending Qaza.
- Re-enabling reconciles rather than blindly adding another reminder.

## Part 5 — Disable Workflow ✅

- Cancels the recurring reminder when switched OFF.
- Preserves the selected time.
- Persists the disabled state.
- Prevents rescheduling while OFF.

## Part 6 — Pending-Qaza Scheduling Rule ✅

- Recurring reminder exists only when enabled + permission granted + pending Qaza exists.
- Pending Qaza appearing causes scheduling.
- Last pending Qaza disappearing causes cancellation.
- A single recurring notification ID is used.

## Part 7 — Reminder Time Workflow ✅

- Native Material `showTimePicker` is used.
- Default time is 8:00 PM.
- Selection saves automatically.
- Enabled + pending changes reschedule immediately.
- Disabled changes only update the saved preference.
- Invalid times are rejected.

## Part 8 — Test Notification ✅

- Dedicated one-shot Test Notification action.
- Requires granted permission.
- Does not alter the daily reminder preference.
- Uses a separate notification ID.
- Clear success/failure feedback is shown.

## Part 9 — Persistence & Restore ✅

- Reminder enabled/disabled state is persisted per active account.
- Reminder hour/minute are persisted per active account.
- Device permission remains OS-derived.
- Same-account restore returns the saved configuration.
- Different accounts receive isolated defaults/configuration.

## Part 10 — Runtime Reconciliation ✅

- Permission is checked at initialization and refreshed when the app resumes.
- Permission changes reconcile the actual recurring schedule.
- Pending-Qaza ledger changes reconcile scheduling automatically.
- Revoked permission cancels active scheduling without silently changing the stored preference.
- Restored permission can reactivate scheduling when pending Qaza exists.

## Part 11 — Theme & Responsive UX ✅

- Notification UI uses Material 3 components and the app's existing theme tokens.
- No custom hardcoded notification colors are introduced.
- Enabled, disabled, blocked, unavailable, and operational states use standard themed states.
- Layout remains a single scrollable screen with compact spacing and standard touch targets.
- Long status/copy text is allowed to wrap rather than overflow.
- Time selection and actions remain accessible on narrow displays.
- Light and dark mode reuse the app theme automatically.

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

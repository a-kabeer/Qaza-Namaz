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
| 3 | Production Notifications UI | ☐ |
| 4 | Enable workflow | ☐ |
| 5 | Disable workflow | ☐ |
| 6 | Pending-Qaza scheduling rule | ☐ |
| 7 | Reminder time workflow | ☐ |
| 8 | Test notification | ☐ |
| 9 | Persistence & restore | ☐ |
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
- `NotificationPermissionStatus` now explicitly represents `notRequested`, `granted`, `denied`, `unavailable`, and `restricted` states.
- `NotificationScheduleStatus` separates the user's reminder preference from the derived operational state: `disabled`, `permissionRequired`, `noPendingQaza`, or `scheduled`.
- Scheduling decisions are derived from enablement + permission + pending-Qaza state instead of treating `enabled` as proof that a reminder is actually scheduled.
- The selected reminder time remains part of the persisted configuration and is independent from whether the reminder is currently active.
- Permission status and pending-Qaza state remain runtime-derived, while the user preference and reminder time remain locally persisted.
- Re-enabling an already-enabled reminder reconciles the actual schedule instead of silently skipping reconciliation.

### Part 2 verification coverage
- Tests now cover the default state and derived schedule state.
- Tests cover the permission-request path with a distinct initial permission-status simulation.
- Tests cover disabled, scheduled, no-pending, and denied/permission-required state transitions.

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

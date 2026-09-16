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
| 1 | Audit & baseline | ☐ |
| 2 | Notification state model | ☐ |
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

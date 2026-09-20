# Notification Implementation Status

## Current status

**Phase:** Notification access hardening  
**Branch:** `rebuild/notification-access-hardening`  
**PR:** #41  
**Tracking state:** CI verified; real-device smoke test pending

## Problem addressed

The daily Qaza reminder flow had multiple failure modes that could leave the user with a generic notification error even when the Android notification system itself was available.

## Completed in this implementation

- [x] Keep `flutter_local_notifications` and the existing timezone scheduler.
- [x] Keep Android notification permission declaration and scheduled-notification receivers.
- [x] Detect Android app-level notification access separately from the runtime permission state.
- [x] Detect the Qaza reminder notification channel being disabled.
- [x] Keep scheduler initialization alive when the reminder channel is disabled so the UI can provide a recovery action.
- [x] Open Android notification settings directly; when the Qaza reminder channel is disabled, target that channel instead of the generic app page.
- [x] Add explicit UI states for app notifications disabled and reminder channel disabled.
- [x] When the user enables the reminder while access is blocked, preserve the user's reminder intent and open the relevant Android settings.
- [x] Reconcile permission/access state again when the app resumes.
- [x] Add English and Urdu recovery copy.
- [x] Add widget coverage for app-level and channel-level blocked states.

## Remaining verification

- [x] Run `flutter analyze`.
- [x] Run the full Flutter test suite on Linux.
- [x] Build the Android debug APK in CI.
- [x] Run Windows CI tests and confirm they remain unaffected.
- [x] Run Linux CI tests and confirm they remain unaffected.

**CI result:** Flutter CI run 1426 passed all four jobs: Analyze, Tests (Linux), Tests (Windows), and Android debug/release APK job. Production release signing is not configured, so the release APK step was skipped.
- [ ] Real-device smoke test on Android 13+:
  - [ ] Fresh install and notification permission prompt.
  - [ ] Deny permission and confirm the app shows a usable recovery state.
  - [ ] Permanently block permission and confirm Open Settings works.
  - [ ] Disable the Qaza reminder channel and confirm the app opens the exact channel settings.
  - [ ] Re-enable notifications in Android settings and return to the app.
  - [ ] Confirm the daily reminder is automatically reconciled when pending Qaza exists.
  - [ ] Send a test notification and confirm actual delivery.
  - [ ] Disable the reminder and confirm cancellation.
  - [ ] Reboot and verify the scheduled reminder remains recoverable.

## Acceptance criteria

The notification page is considered production-ready when a user can always see which layer is blocking delivery and has a direct recovery action, instead of receiving only a generic "notifications unavailable" state.

The release gate also requires successful CI plus real-device notification delivery verification because CI cannot prove Android system notification delivery.

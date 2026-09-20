# Notification Production Smoke Test

Run this checklist on a real Android device after installing a debug or release build.

## 1. Timezone initialization
- Open Settings → Notifications.
- Confirm the page loads without an initialization error.
- Change the device timezone, reopen the page, and confirm the page still loads.

## 2. Notification permission
- Start with notifications disabled for the app.
- Enable Daily Reminder.
- Confirm the Android notification permission prompt appears when applicable.
- Confirm the app reports the resulting permission state correctly.

## 3. Scheduling
- Add at least one pending Qaza record.
- Enable Daily Reminder.
- Confirm the app reports the configured reminder time as scheduled.
- Verify the notification channel exists in Android system notification settings.

## 4. Delivery
- Use Send Test Notification.
- Confirm the notification appears on the device.
- Confirm the app remains usable after the notification is delivered or tapped.

## 5. Cancellation
- Disable Daily Reminder.
- Reopen the app and confirm the reminder is shown as disabled.
- Check pending notifications/system state and confirm the daily reminder is no longer scheduled.

## 6. Recovery
- Permanently deny notification permission.
- Confirm the Notifications page remains usable and offers Open Settings.
- Enable notification permission in Android settings.
- Return to the app and confirm permission is detected and an enabled reminder with pending Qaza is reconciled.

## 7. Light/dark and RTL
- Repeat the permission and schedule-status review in light mode, dark mode, and Urdu/RTL.
- Confirm unavailable, blocked, granted, and scheduled states remain readable and unambiguous.

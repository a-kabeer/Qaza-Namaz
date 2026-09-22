# Notification rework & device QA

**Priority:** P1  
**Status:** **Merged — Device QA Pending**

_Reconciled 2026-09-22 against `main` @ 505a828. The six software items are implemented and covered by `test/task3j_notifications_test.dart`. Everything else on this list is a hardware matrix and cannot be ticked from the repository._

## Task checklist

Software:

- [x] Reminder settings UX — `lib/features/settings/notifications_screen.dart`
- [x] Reminder time — `setTime(hour, minute)`, persisted per user
- [x] Only remind when Qaza remain — `NotificationScheduleStatus.noPendingQaza`
      cancels a scheduled reminder when nothing is pending
- [x] Repeat — daily schedule
- [x] Test notification — `sendTestNotification()`
- [x] Notification content — localized in English and Urdu

Device QA matrix — none of these have been run:

- [ ] Android 13
- [ ] Android 14
- [ ] Android 15
- [ ] Android 16
- [ ] Pixel
- [ ] Samsung
- [ ] Permission denied/later granted
- [ ] Channel blocked/app notifications disabled
- [ ] Reboot
- [ ] Battery saver
- [ ] Doze
- [ ] Timezone change
- [ ] Notification tap
- [ ] Cold start
- [ ] App update

## Current evidence

Physical-device QA is required.

## Definition of Done

- [ ] Implementation
- [ ] Unit/widget tests
- [ ] Regression tests
- [ ] Analyze
- [ ] CI
- [ ] Device QA where required
- [ ] UX review
- [ ] Documentation
- [ ] Merge

## Evidence log

| Date | Status | Evidence |
|---|---|---|
| 2026-09-20 | Not started | Fresh tracking document created from the shared master plan. |

**Rule:** update this tracking file, not the master plan, when status changes.

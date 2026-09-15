# Qaza Namaz App — Project Status

## Current Task
Task 3A–3J — COMPLETE TASK 3, RIVERPOD-FIRST.

## Completion Status
- Task 1: COMPLETE & VERIFIED — Qaza ledger business workflow and tests.
- Task 2: COMPLETE & VERIFIED — Firebase Authentication, Google Sign-In, Firestore persistence, user-scoped rules, and Android runtime verification.
- Task 3A: COMPLETE — Google authentication lifecycle, splash/welcome/sign-in flow, Firebase session restoration, persisted first-time setup, sign-out, and active UID session scoping. Unsupported placeholder authentication controls were removed.
- Task 3B: COMPLETE — Riverpod-based app shell, live dashboard totals/progress, Qaza navigation, and loading/error/empty/refresh states.
- Task 3C: COMPLETE — single/range Qaza entry, Gregorian/Hijri calendar integration, review-before-save, future-date protection, duplicate-safe records, and Gregorian original-date preservation.
- Task 3D: COMPLETE — oldest-first completion, prayer-wise views, multi-select/select-all/clear-all, real completion timestamps, double-completion protection, and independent Witr handling.
- Task 3E: COMPLETE — centralized history/progress providers, newest completion ordering, original-vs-completion dates, and shared loading/error/empty/refresh handling.
- Task 3F: COMPLETE — system/light/dark theme provider, shared Stitch design system/components, Firebase account display, and provider-driven sign-out/settings UI.
- Task 3G: COMPLETE — Gregorian + Hijri Umm al-Qura calendar engine, reusable single/range calendar picker, alternate-calendar summaries, future/minimum-date protection, calendar boundary handling, canonical Gregorian storage, and Add Qaza integration. Calendar dependencies are consumed through the Riverpod composition root rather than constructor-threaded services/user IDs.
- Task 3H: COMPLETE — offline-first local persistence, UID-isolated cache, durable outbox, connectivity-triggered sync, retry behavior, deterministic merge rules, and sync status reporting.
- Task 3I: COMPLETE — versioned JSON export/import, full pre-import validation, duplicate protection, deterministic conflict handling, current-account ownership remapping, preview/confirmation UI, and Android-compatible file handling.
- Task 3J: IMPLEMENTED — Android local daily reminders, permission handling, persisted reminder settings, single stable schedule, inexact scheduling, reboot/package-replacement rescheduling, and dedicated tests.
- Architecture Refactor: COMPLETE — Riverpod composition root and shared derived ledger state remove repeated dependency threading and duplicate reads.
- Cleanup: COMPLETE — unsupported authentication placeholders and temporary scratch/reference artifacts removed where confirmed unused.
- Performance: COMPLETE for this scope — local-first reads/writes, shared ledger state, single-flight synchronization, linear bulk-add duplicate detection, const/shared UI components, and resource disposal.

## Current Architecture
`UI → Riverpod providers/notifiers → Domain/Data services → QazaRepository → OfflineFirstQazaRepository → local cache + Firestore synchronization`.

The Qaza ledger remains based on the single `QazaRecord` entity. Export/import uses transfer-specific analysis/result DTOs but never replaces the ledger model. Notifications use a small scheduler abstraction behind a Riverpod-driven settings notifier. Calendar conversion and the Add Qaza flow use the shared `calendarEngineProvider`.

## Task 3G Calendar Boundary
Task 3G is no longer frozen. Its calendar engine, picker, tests, and Add Qaza integration are available for maintenance and improvement. The Gregorian date remains canonical for Qaza records; Hijri is a derived display/selection view using the configured Umm al-Qura adapter.

## Task 3H Data Integrity Boundary
Task 3H remains the source of truth for offline/online persistence. Task 3I and normal Qaza writes use the existing repository boundary and therefore remain local-first with durable cloud synchronization.

## Task 3I Export Schema
Version 1:
```json
{
  "schemaVersion": 1,
  "exportedAt": "ISO-8601 timestamp",
  "appVersion": "release version",
  "records": [
    {
      "id": "...",
      "userId": "...",
      "prayerType": "fajr|zuhr|asr|maghrib|isha|witr",
      "originalDate": "ISO-8601 timestamp",
      "status": "pending|completed",
      "completedAt": "ISO-8601 timestamp or null",
      "createdAt": "ISO-8601 timestamp",
      "updatedAt": "ISO-8601 timestamp"
    }
  ]
}
```
Derived counters are not exported as the ledger source of truth.

## Task 3I Import Policy
- The entire document is parsed and validated before any mutation.
- Schema version, envelope metadata, record structure, prayer type, status, dates, timestamps, ownership metadata, duplicate IDs, and duplicate prayer/date combinations are validated.
- Pending records cannot contain `completedAt`; completed records must contain it.
- Imported ownership is remapped to the currently authenticated UID and stable IDs are regenerated from current UID + prayer + original date.
- Existing records are never blindly overwritten.
- Imported completed state promotes an existing pending record; existing completed state is preserved against imported pending data.
- Re-importing the same file is idempotent.
- Invalid imports cannot partially mutate the ledger.
- Import/export never delete local or cloud data.

## Task 3J Notification Policy
- Daily reminder is device-local; no remote notification service is used.
- Reminder settings are persisted with `shared_preferences`.
- A fixed notification ID is used; schedule operations cancel the existing ID before scheduling so repeated enable/time changes do not create duplicate reminders.
- Android 13+ notification permission is requested when enabling reminders.
- Scheduling uses the device IANA timezone and `AndroidScheduleMode.inexactAllowWhileIdle`, so exact-alarm permission is not required.
- `RECEIVE_BOOT_COMPLETED`, package-replacement and quick-boot receiver declarations allow the plugin to restore scheduled notifications after restart/update.

## Validation
The repository has dedicated tests for Tasks 3A–3I behavior plus Task 3J notification settings/scheduling logic. GitHub Actions is configured to run `flutter clean`, `flutter pub get`, `flutter analyze`, `flutter test`, `flutter build apk --debug`, and `flutter build apk --release` on the final CI path. Physical-device confirmation of Android notification delivery and file-picker UX remains environment-dependent and is not claimed as automated validation.

## Remaining Issues / Technical Debt
- Physical-device verification of Android notification permission, reboot rescheduling, and export/import picker behavior remains environment-dependent.
- Existing Flutter 3.27 informational `withOpacity` deprecation findings remain outside the functional task scope.
- The app currently exposes Google as the connected authentication provider; no unsupported email/phone/WhatsApp authentication is presented as functional.
- Urdu localization and other separately scoped features remain intentionally unimplemented.

## Scope Boundary
Task 3G is part of the completed Task 3 scope and may be modified when a real calendar defect, compatibility issue, or UX improvement is identified. Changes must preserve canonical Gregorian storage, Umm al-Qura conversion, future-date protection, and range integrity.

## Last Updated
2026-09-15

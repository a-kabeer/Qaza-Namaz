# Qaza Namaz App — Project Status

## Current Task
Task 3I — Export, Import & Safe Qaza Data Management.

## Completion Status
- Task 1: COMPLETE & VERIFIED — Qaza ledger business workflow and tests.
- Task 2: COMPLETE & VERIFIED — Firebase Authentication, Google Sign-In, Firestore persistence, user-scoped rules, and Android runtime verification.
- Task 3A–3F: COMPLETE — Stitch-derived authentication, dashboard, Qaza flows, history/progress, theme, settings, and account work.
- Task 3G: FROZEN / PRESERVED — Gregorian + Hijri Umm al-Qura calendar implementation remains unchanged by Task 3H/3I/refactor work.
- Task 3H: COMPLETE — offline-first local persistence, UID-isolated cache, durable outbox, connectivity-triggered sync, retry behavior, deterministic merge rules, and sync status reporting are implemented and tested.
- Architecture Refactor: COMPLETE — Riverpod composition root and derived ledger providers centralize application state and remove repeated dependency threading from production screens.
- Cleanup: COMPLETE — temporary Cline/scratch/reference dumps removed from the repository tree.
- Performance: COMPLETE for the refactor scope — shared in-memory ledger state, local-first reads/writes, single-flight synchronization, linear bulk-add duplicate detection, and resource disposal are implemented.
- Task 3I: IMPLEMENTED — versioned JSON export, complete pre-import validation, duplicate protection, deterministic conflict handling, current-account ownership remapping, preview/confirmation UI, and native Android-compatible file handling.

## Current Architecture
`UI → Riverpod providers/notifiers → QazaService / QazaDataTransferService → QazaRepository → OfflineFirstQazaRepository → local cache + Firestore synchronization`.

`QazaRecord` remains the single ledger entity. Task 3I adds a transfer service and validation/preview DTOs, not a second record model.

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
Derived counters are never exported as the ledger source of truth.

## Task 3I Import Policy
- The entire document is parsed and validated before any mutation.
- Schema version, envelope metadata, record structure, prayer type, status, dates, timestamps, ownership metadata, duplicate IDs, and duplicate prayer/date combinations are validated.
- A pending record cannot contain `completedAt`; a completed record must contain it.
- Imported ownership is explicitly remapped to the currently authenticated Firebase UID. Stable IDs are regenerated from `currentUserId + prayerType + originalDate`.
- Existing records are never blindly overwritten.
- Pending + imported completed promotes the existing record to completed.
- Existing completed state is preserved against imported pending data.
- Re-importing the same file is idempotent.
- Import uses the existing repository boundary, so new/changed data is local-first and enters the Task 3H outbox for cloud synchronization.
- Export and import never delete local or cloud data.

## Task 3I UI / File Handling
Settings → Data & Cloud → Export & Import provides:
- native JSON save dialog for export;
- native JSON file picker for import;
- validation error handling;
- import preview and explicit confirmation;
- clear explanation that export/import/sign-out/uninstall are not cloud deletion operations.

The implementation uses `file_picker ^10.3.10`, selected for compatibility with the project's Flutter/Dart baseline and the existing Android toolchain.

## Task 3I Tests
`test/task3i_data_transfer_test.dart` covers:
- valid export;
- empty export;
- round-trip semantic preservation;
- malformed JSON;
- invalid schema;
- duplicate IDs;
- duplicate prayer/date combinations;
- repeated import idempotency;
- completed-record preservation;
- pending-to-completed conflict merge;
- originalDate and completedAt preservation;
- cross-user ownership remapping;
- invalid-file atomicity (no partial writes).

## Task 3H Boundary
Task 3H local cache/outbox/sync behavior remains the source of truth for offline/online persistence. Task 3I does not replace, bypass, or redesign that layer.

## Task 3G Scope Boundary
All existing Task 3G calendar engine and picker files/tests remain frozen and are not redesigned or replaced by Task 3I.

## Validation
Task 3I implementation is committed and ready for CI validation with `flutter pub get`, `flutter analyze`, and `flutter test`. Android native file-picker behavior remains part of runtime verification on a real device.

## Remaining Technical Debt
- Physical-device verification of the complete Task 3I save/open/import lifecycle remains environment-dependent.
- Existing Flutter 3.27 informational deprecation findings (`withOpacity`) remain outside this task's functional scope.
- Urdu localization, notifications, and other separately scoped features remain intentionally unimplemented.

## Last Updated
2026-09-15

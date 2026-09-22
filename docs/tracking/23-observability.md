# Production observability

**Priority:** P1  
**Status:** **Partially Implemented — Remaining Scope**

_Reconciled 2026-09-22 against `main` @ 505a828. A vendor-neutral diagnostics port was added in this pass (`lib/core/diagnostics/diagnostics.dart`) and wired at every failure site this task names. Redaction is structural, not a policy: the API takes an area, a short code and an error, and only the error's runtime type plus a redacted message ever reach a sink. Covered by `test/diagnostics_test.dart` (15 tests). What remains is the vendor adapter, which needs console configuration._

## Task checklist

- [ ] Crashlytics or equivalent — **the equivalent is in place, the vendor is
      not.** `DiagnosticsService` with `DebugDiagnostics`, `BufferedDiagnostics`,
      `NoopDiagnostics` and `FanOutDiagnostics` ships, and `diagnosticsProvider`
      is the single override point. Adding Crashlytics is one provider override
      plus a Firebase console step, which is why this stays unticked.
- [x] Crash-rate monitoring — `FlutterError.onError` and
      `PlatformDispatcher.instance.onError` in `main.dart`, both reported as
      fatal
- [x] Authentication failure monitoring — `FirebaseAuthRepository`
- [x] Notification initialization monitoring — `QazaNamazApp`
- [x] Notification scheduling monitoring — `NotificationSettingsNotifier`
- [x] Sync failure monitoring — `OfflineFirstQazaRepository` hydrate/sync
- [x] Import failure monitoring — `QazaDataManagementScreen`
- [x] Database migration monitoring — the `database` startup step in `main.dart`
- [x] Sensitive-data logging audit — emails, dates, ids, tokens and counts are
      stripped by `redactDiagnosticMessage`, messages are capped, and a test
      walks every file under `lib/` to assert nothing logs a record, user id or
      token directly

## Current evidence

Track only non-sensitive diagnostics; never log complete Qaza records, private history, credentials, or tokens.

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

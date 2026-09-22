# Automated quality gates

**Priority:** P1  
**Status:** **Partially Implemented — Remaining Scope**

_Reconciled 2026-09-22 against `main` @ 505a828. The real `.github/workflows/flutter-ci.yml` runs five jobs: Analyze (with a `dart format` check), Tests (Linux), Tests (Windows), Firestore security rules, and Android debug and release artifacts (debug APK, signed release APK, release AAB). Remaining scope: analysis runs as `flutter analyze --no-fatal-infos --no-fatal-warnings`, so infos and warnings cannot fail the build, and there is no coverage threshold, no golden test job and no `integration_test` job._

## Task checklist

Checked items are enforced by a job in `.github/workflows/flutter-ci.yml`.

- [x] Formatting — `dart format lib test` in the Analyze job
- [x] Static analysis — Analyze job, but see the caveat above: infos and warnings do not fail it
- [x] Unit tests — Tests (Linux)
- [x] Widget tests — Tests (Linux)
- [x] Accessibility tests — part of `flutter test`, not a separate gate
- [x] Database tests — part of `flutter test`
- [x] Sync tests — part of `flutter test`
- [x] Guest migration tests — part of `flutter test`
- [x] Calculator tests — part of `flutter test`
- [x] Notification tests — part of `flutter test`
- [x] Linux tests — Tests (Linux)
- [x] Windows tests — Tests (Windows)
- [x] Android debug build — Android debug and release artifacts
- [x] Android release AAB — Android debug and release artifacts
- [x] Security rule tests — Firestore security rules job
- [x] Release signing — the release job publishes `app-release-apk-signed`
- [x] Target SDK — verified on device: `targetSdk=36`
- [ ] Firebase configuration — depends on console registration, tracked in task 02
- [ ] Coverage threshold — no coverage gate exists
- [ ] Golden/visual tests — no golden job exists
- [ ] End-to-end `integration_test` job — none exists

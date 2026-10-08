# Qaza-Namaz — Phase 0 Baseline & Phase 1 Closure Record

Date: 2026-10-08

## Repository baseline

- Repository: a-kabeer/Qaza-Namaz
- Default branch: main
- Offline implementation branch: feat/pure-offline-backup-revision
- Phase 1 PR: #263
- Baseline/main SHA: af5cc62223b181e243daa4f4667c493c49221401
- Offline branch before remediation: 46982362bcbe7c75e778f51d404743bf96a8c32c
- Flutter: 3.47.4 stable
- Android Gradle Plugin: 9.0.1
- Kotlin: 2.3.20
- NDK: 28.2.13676358
- Application ID: com.qaza_namaz.com

## Phase 0 closure evidence

The repository has a complete recursive tree inventory, obsolete task/status artifacts are archived, and the offline branch has an explicit architecture-policy gate.

CI evidence already established:
- Drift code generation succeeds.
- Offline architecture policy succeeds.
- Flutter analyze succeeds.
- Android release APK builds.
- Android release AAB builds.
- Release merged manifest contains no INTERNET permission.

## Phase 1 architecture boundary

Production runtime excludes Firebase, Google Sign-In, Firestore, Firebase App Check, WorkManager, connectivity_plus, Google APIs, and cloud-adapter runtime paths.

Geolocation remains intentionally enabled through geolocator and Google Play Services location. Prayer-time, timezone, offline GeoNames, Qibla, and related local capabilities remain local/device capabilities.

## Closure gates

Phase 1 is not considered closed until all of these are green:
1. Dart formatting.
2. Full Flutter test suite with zero failures.
3. Offline architecture policy.
4. Android release APK.
5. Android release AAB.
6. Release INTERNET-permission assertion.
7. Android offline startup smoke test.
8. PR review/merge.

Physical human-device QA remains a release-certification activity outside repository automation.

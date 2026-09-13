# Qaza Namaz App — Project Status

## Current Task
Task 2 — Google Authentication + Cloud Persistence

## Overall Progress
Task 1 verified; Task 2 foundation implemented and awaiting local Firebase project configuration and runtime verification.

## Task Status
- Task 1: 🟢 COMPLETE & VERIFIED — local `flutter test` passed with 12/12 tests.
- Task 2: 🟡 PARTIALLY COMPLETE — Firebase dependencies, Google authentication repository, Firestore Qaza repository, and user-scoped Firestore rules implemented; Firebase project configuration and device/runtime verification remain.
- Task 3: 🔴 NOT STARTED
- Task 4: 🔴 NOT STARTED
- Task 5: 🔴 NOT STARTED
- Task 6: 🔴 NOT STARTED
- Task 7: 🟡 PARTIALLY COMPLETE — core business logic implemented as part of Task 1
- Task 8: 🔴 NOT STARTED
- Task 9: 🔴 NOT STARTED
- Task 10: 🔴 NOT STARTED
- Task 11: 🔴 NOT STARTED
- Task 12: 🔴 NOT STARTED
- Task 13: 🔴 NOT STARTED
- Task 14: 🟡 PARTIALLY COMPLETE — core unit tests exist; full QA not started
- Task 15: 🔴 NOT STARTED

## Task 2 Implemented
- Added `firebase_core`, `firebase_auth`, `cloud_firestore`, and official `google_sign_in` dependencies.
- Added a domain-level `AppUser` entity.
- Added an `AuthRepository` contract independent of Firebase implementation details.
- Added `FirebaseAuthRepository` for Google Sign-In through Firebase Authentication.
- Added `FirestoreQazaRepository` implementing the existing Qaza repository contract.
- Firestore records are user-scoped at `users/{uid}/qazaRecords/{recordId}`.
- Existing deterministic Qaza record IDs are preserved for duplicate protection and synchronization.
- Firestore completion operations remain idempotent and preserve the existing domain workflow.
- Added `firestore.rules` enforcing authenticated user ownership by Firebase UID.
- Android Cloud Firestore offline persistence is supported by the Firebase SDK and will be used by the app as the cloud repository is integrated.

## Task 2 Remaining
- Create/select the Firebase project.
- Install/configure Firebase CLI and FlutterFire CLI locally.
- Run `flutterfire configure` for the Android app and generate `lib/firebase_options.dart`.
- Enable Google as a Firebase Authentication provider.
- Create the Cloud Firestore database.
- Deploy `firestore.rules`.
- Wire Firebase initialization into `main.dart` after the generated Firebase configuration exists.
- Replace the placeholder in-memory repository in the application composition root with the authenticated Firestore repository.
- Connect the authentication state to the application navigation/UI in later UX work.
- Run `flutter pub get`, `flutter test`, and Android runtime sign-in/Firestore tests locally.

## Known Limitations / Verification
- Firebase project configuration is NOT VERIFIED from GitHub because it is environment/project-specific and must be generated locally with FlutterFire CLI.
- Google Sign-In cannot be runtime-verified until Firebase is configured and the Android app's signing configuration/SHA-1 is registered as required by Firebase.
- The repository currently still uses the in-memory repository in the placeholder HomePage composition; replacing that composition is intentionally gated on Firebase configuration.

## Last Verified
2026-09-13 — Task 1 local test result reported by user: `00:03 +12: All tests passed!`; Task 2 source implementation audited and committed to `main`.

## Next Action
Configure Firebase locally with `flutterfire configure`, then wire Firebase initialization and the Firestore/auth repositories into the app and run the full test suite plus Android Google Sign-In/Firestore verification.

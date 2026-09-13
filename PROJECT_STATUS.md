# Qaza Namaz App — Project Status

## Current Task
Task 2 — Google Authentication + Cloud Persistence

## Overall Progress
Task 1 is verified. Task 2 implementation and Firebase/Android project configuration are now committed; Android runtime verification remains pending.

## Task Status
- Task 1: 🟢 COMPLETE & VERIFIED — local `flutter test` passed with 12/12 tests; later regression suite passes with 13 tests.
- Task 2: 🟡 IMPLEMENTED — Firebase configuration, initialization, Google authentication gate, Firestore repository integration, and user-scoped rules are implemented; Android runtime verification remains.
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
- Task 14: 🟡 PARTIALLY COMPLETE — core unit/widget tests exist; full QA not started
- Task 15: 🔴 NOT STARTED

## Task 2 Implemented
- Added Firebase Core, Firebase Authentication, Cloud Firestore, and Google Sign-In dependencies.
- Generated `lib/firebase_options.dart` with FlutterFire CLI for the Android Firebase project.
- Generated and committed the Android Flutter platform project and `google-services.json`.
- Added a domain-level `AppUser` entity.
- Added an `AuthRepository` contract independent of Firebase implementation details.
- Added `FirebaseAuthRepository` for Google Sign-In through Firebase Authentication.
- Added an authentication gate with signed-out Google Sign-In UI and signed-in application routing.
- Added Firebase initialization in `main.dart` before application startup.
- Added `FirestoreQazaRepository` implementing the existing Qaza repository contract.
- Replaced the HomePage demo user/in-memory composition with dependency-injected authenticated user ID and Firestore repository.
- Firestore records are user-scoped at `users/{uid}/qazaRecords/{recordId}`.
- Existing deterministic Qaza record IDs are preserved for duplicate protection and synchronization.
- Firestore completion operations remain idempotent and preserve the existing domain workflow.
- Added `firestore.rules` enforcing authenticated user ownership by Firebase UID.
- Updated widget smoke testing to inject fake auth and in-memory repositories without requiring Firebase in Flutter test execution.

## Task 2 Remaining
- Verify that the selected Firebase project has Google as an enabled Authentication provider.
- Verify/create the Cloud Firestore database in the selected Firebase project.
- Deploy `firestore.rules` to the Firebase project.
- Verify the Android app's signing SHA-1/SHA-256 configuration required for Google Sign-In, especially for the local debug build.
- Run the app on an Android device/emulator and complete Google Sign-In.
- Verify Firebase Auth returns the expected signed-in user and UID.
- Verify Qaza records can be written to and read from Firestore under the authenticated UID.
- Verify sign-out and subsequent sign-in preserve the same cloud data.
- Verify Firestore access is rejected for another user's UID.
- Run the final local regression suite and update this status only after runtime verification succeeds.

## Known Limitations / Verification
- Firebase configuration is now present in GitHub, including `lib/firebase_options.dart` and Android configuration, but Firebase console settings and Android runtime behavior are NOT VERIFIED by repository inspection alone.
- Google Sign-In runtime behavior is NOT VERIFIED until an Android build is run with the configured Firebase project and signing credentials.
- Firestore runtime read/write and security-rule behavior are NOT VERIFIED until exercised against the Firebase project.
- Task 3 remains intentionally separate: visual/UI redesign will be handled after Task 2 backend/auth verification.

## Last Verified
2026-09-13 — User reported `flutter analyze` with no issues and `flutter test` with 13 tests passing after Firebase configuration. Repository-side Task 2 integration was then completed through Firebase initialization, authentication gating, and Firestore dependency injection.

## Next Action
Pull the latest `main` branch locally, run `flutter pub get`, `flutter analyze`, and `flutter test`, then run the Android app and perform the Google Sign-In + Firestore runtime verification checklist above.

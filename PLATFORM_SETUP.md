# Platform Setup

This package contains the Dart/Flutter application source and project configuration.

After extracting it, run:

~~~bash
flutter create .
flutter pub get
flutter test
flutter run
~~~

## Android Google Authentication

The Android applicationId is:

~~~text
com.example.qaza_namaz_task1_flutter
~~~

android/app/google-services.json contains the matching Firebase Android client and an Android OAuth client for that package. lib/firebase_options.dart uses the same Firebase project/app ID.

The Firebase Console must also have the Google provider enabled for the qaza-nmz project. The signing certificate fingerprints registered in Firebase must match the key actually used to install the APK:

- debug APK: the local/CI debug signing certificate
- release APK: the release keystore certificate

The repository intentionally does not contain the release keystore, so the release SHA-1/SHA-256 fingerprints cannot be verified from source alone. Register both fingerprints for every signing certificate used to distribute the app, then download/update google-services.json when Firebase configuration changes.

Useful failure codes are no longer hidden by the app. Examples:

- firebase-auth/operation-not-allowed: check that Google is enabled in Firebase Authentication.
- Android Google sign-in platform errors such as sign_in_failed: check package ID, OAuth client, and SHA-1/SHA-256 fingerprints.
- Missing Google ID token: check the Android OAuth configuration and Firebase Google provider setup.

The regression suite checks that the Android application ID, Firebase Android client, OAuth package, and generated Firebase app ID remain internally consistent.

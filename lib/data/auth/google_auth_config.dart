/// Non-secret identifiers used to make the Android Google OAuth contract
/// explicit and testable. These values must match google-services.json for the
/// qaza-nmz Firebase project.
const String googleFirebaseProjectId = 'qaza-nmz';
const String googleAndroidApplicationId =
    'com.example.qaza_namaz_task1_flutter';
const String googleFirebaseAndroidAppId =
    '1:895430705174:android:1e8d352d65428a4a3c7537';

/// Every Android OAuth signing certificate SHA-1 registered for
/// [googleAndroidApplicationId] in the Firebase project, lowercase and
/// unseparated, exactly as google-services.json stores them.
///
/// Google Play services matches the calling app by package name *and* signing
/// certificate before it will mint an ID token. A build signed with anything
/// else is rejected at the Credential Manager boundary, which reaches the
/// device as "[16] Account reauth failed" and nothing more. Keeping the list
/// here lets the running app say so precisely; google_auth_configuration_test
/// asserts it still matches google-services.json.
const List<String> googleAndroidCertificateSha1s = <String>[
  '3ab6c8b508a68579254d31983716f5d2babd418d',
];

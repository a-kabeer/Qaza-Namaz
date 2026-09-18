/// Application metadata used in user-visible data exports.
///
/// Keep this aligned with the `version:` in pubspec.yaml. Export schema
/// versioning is independent from the app release version.
const appVersion = '0.2.0+2';

/// The release version without the build number, for display to users.
///
/// Derived from [appVersion] so the version is stated in exactly one place.
final appDisplayVersion = appVersion.split('+').first;

const qazaExportSchemaVersion = 1;

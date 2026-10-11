import 'package:flutter_native_oss_licenses/flutter_native_oss_licenses.dart';

/// Registers native dependency notices with Flutter's standard licence registry.
///
/// Keep this in the application composition root so both the offline app and
/// the optional cloud host expose native licences in their built-in licence page.
void registerAppLicenses() {
  registerNativeLicenses();
}

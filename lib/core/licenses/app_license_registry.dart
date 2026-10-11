import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_oss_licenses/flutter_native_oss_licenses.dart';

bool _registered = false;

/// Registers native dependency notices and the app's manually bundled notices.
///
/// The app and cloud host share this registry. Their asset bundles expose the
/// notice files at different keys because the cloud host consumes Qaza Namaz
/// as a path dependency.
void registerAppLicenses() {
  if (_registered) return;
  _registered = true;

  registerNativeLicenses();
  LicenseRegistry.addLicense(() async* {
    for (final entry in await loadBundledAppLicenseEntries()) {
      yield entry;
    }
  });
}

/// Loads the app-owned notices that are bundled in both app asset bundles.
///
/// Kept separate from the global [LicenseRegistry] stream so callers can
/// verify the bundled notices without consuming unrelated package registries.
Future<List<LicenseEntry>> loadBundledAppLicenseEntries() async {
  final fontNotice = await _loadBundledNotice('noto_nastaliq_urdu.txt');
  final sqliteNotice = await _loadBundledNotice('sqlite3_multiple_ciphers.txt');

  return [
    LicenseEntryWithLineBreaks(['Noto Nastaliq Urdu font'], fontNotice),
    LicenseEntryWithLineBreaks(
      ['SQLite3MultipleCiphers (sqlite3mc)'],
      sqliteNotice,
    ),
  ];
}

Future<String> _loadBundledNotice(String fileName) async {
  try {
    return await rootBundle.loadString('licenses/$fileName');
  } on FlutterError {
    return rootBundle.loadString('packages/qaza_namaz/licenses/$fileName');
  }
}

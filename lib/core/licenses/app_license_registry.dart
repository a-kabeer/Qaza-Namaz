import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_oss_licenses/flutter_native_oss_licenses.dart';

bool _registered = false;

/// Registers native dependency notices and the bundled Urdu font licence.
///
/// The app and cloud host share this registry. Their asset bundles expose the
/// notice at different keys because the cloud host consumes Qaza Namaz as a
/// path dependency.
void registerAppLicenses() {
  if (_registered) return;
  _registered = true;

  registerNativeLicenses();
  LicenseRegistry.addLicense(() async* {
    final notice = await _loadNotoNastaliqUrduNotice();
    yield LicenseEntryWithLineBreaks(['Noto Nastaliq Urdu font'], notice);
  });
}

Future<String> _loadNotoNastaliqUrduNotice() async {
  try {
    return await rootBundle.loadString('licenses/noto_nastaliq_urdu.txt');
  } on FlutterError {
    return rootBundle.loadString(
      'packages/qaza_namaz/licenses/noto_nastaliq_urdu.txt',
    );
  }
}

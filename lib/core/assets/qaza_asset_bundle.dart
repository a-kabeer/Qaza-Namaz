import 'package:flutter/services.dart';

/// Loads an app-owned asset whether Qaza Namaz is the Flutter application or
/// is embedded as a path dependency in the optional cloud host.
Future<String> loadQazaAssetString(
  String path, {
  AssetBundle? bundle,
}) async {
  final assets = bundle ?? rootBundle;
  try {
    return await assets.loadString(path);
  } catch (_) {
    final packagePath = path.startsWith('packages/qaza_namaz/')
        ? path
        : 'packages/qaza_namaz/$path';
    return assets.loadString(packagePath);
  }
}

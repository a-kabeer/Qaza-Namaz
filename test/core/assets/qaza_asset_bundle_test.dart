import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/core/assets/qaza_asset_bundle.dart';

void main() {
  test('prefers the normal app asset path when available', () async {
    final bundle = _MapAssetBundle({
      'assets/sample.txt': 'app asset',
      'packages/qaza_namaz/assets/sample.txt': 'package asset',
    });

    expect(
      await loadQazaAssetString('assets/sample.txt', bundle: bundle),
      'app asset',
    );
  });

  test('falls back to the package namespace when embedded', () async {
    final bundle = _MapAssetBundle({
      'packages/qaza_namaz/assets/sample.txt': 'embedded asset',
    });

    expect(
      await loadQazaAssetString('assets/sample.txt', bundle: bundle),
      'embedded asset',
    );
  });
}

class _MapAssetBundle extends CachingAssetBundle {
  _MapAssetBundle(this.assets);

  final Map<String, String> assets;

  @override
  Future<ByteData> load(String key) async {
    final value = assets[key];
    if (value == null) {
      throw StateError('Missing test asset "$key".');
    }
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(value)));
  }
}

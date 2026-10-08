import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('current location resolves Location Services before permission', () {
    final source = File(
      'lib/features/prayer_time/data/prayer_location_repository.dart',
    ).readAsStringSync().replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    final services = source.indexOf(
      'ensureLocationServicesEnabled()',
      source.indexOf('Future<PrayerLocation> getCurrent()'),
    );
    final permissionCheck = source.indexOf(
      'checkPermission()',
      source.indexOf('Future<PrayerLocation> getCurrent()'),
    );
    final permissionRequest = source.indexOf(
      'requestPermission()',
      source.indexOf('Future<PrayerLocation> getCurrent()'),
    );

    expect(services, greaterThanOrEqualTo(0));
    expect(permissionCheck, greaterThan(services));
    expect(permissionRequest, greaterThan(permissionCheck));
  });

  test('location implementation preserves the offline geolocator path with native Google Play Services resolution', () {
    final repository = File(
      'lib/features/prayer_time/data/prayer_location_repository.dart',
    ).readAsStringSync();
    final bridge = File(
      'lib/core/platform/app_location_settings.dart',
    ).readAsStringSync();
    final mainActivity = File(
      'android/app/src/main/kotlin/com/qaza_namaz/com/MainActivity.kt',
    ).readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(repository, contains('geolocator'));
    expect(bridge, contains('geolocator'));
    expect(mainActivity, contains('com.google.android.gms.location'));
    expect(mainActivity, contains('Google'));
    expect(pubspec, contains('geolocator:'));
  });

  test('cancelled Location Services resolution gets an actionable recovery state', () {
    final source = File(
      'lib/features/prayer_time/presentation/prayer_time_page.dart',
    ).readAsStringSync().replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    expect(
      source,
      contains(
        '''PrayerLocationSetupFailure.locationServiceResolutionCancelled =>
          _SetupFailurePresentation(
            message: l10n.prayerTimeLocationServiceRequired,
            actionLabel: l10n.prayerTimeEnableLocation,
          ),''',
      ),
    );
  });
}

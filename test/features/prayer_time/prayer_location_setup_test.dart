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
      'Geolocator.checkPermission()',
      source.indexOf('Future<PrayerLocation> getCurrent()'),
    );
    final permissionRequest = source.indexOf(
      'Geolocator.requestPermission()',
      source.indexOf('Future<PrayerLocation> getCurrent()'),
    );

    expect(services, greaterThanOrEqualTo(0));
    expect(permissionCheck, greaterThan(services));
    expect(permissionRequest, greaterThan(permissionCheck));
  });

  test('cancelled Location Services resolution gets an actionable recovery state', () {
    final source = File(
      'lib/features/prayer_time/presentation/prayer_time_page.dart',
    ).readAsStringSync();

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

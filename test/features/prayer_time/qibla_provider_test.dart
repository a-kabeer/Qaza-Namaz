import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/features/prayer_time/application/qibla_providers.dart';
import 'package:qaza_namaz/features/prayer_time/data/device_compass_service.dart';
import 'package:qaza_namaz/features/prayer_time/domain/prayer_location.dart';
import 'package:qaza_namaz/features/prayer_time/domain/qibla_direction_service.dart';

void main() {
  test('qibla bearing provider uses the saved Prayer Location', () {
    final container = ProviderContainer(
      overrides: [
        qiblaLocationProvider.overrideWithValue(_location()),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(qiblaBearingProvider),
      closeTo(267.741, .01),
    );
  });

  test('sensor unavailable state is supported without disabling static Qibla',
      () async {
    final container = ProviderContainer(
      overrides: [
        compassServiceProvider.overrideWithValue(
          _NoSensorCompassService(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final available = await container.read(
      compassSensorAvailableProvider.future,
    );

    expect(available, isFalse);
  });

  test('true heading conversion uses the local declination sign convention',
      () {
    const service = QiblaDirectionService();

    expect(
      service.trueHeadingFromMagnetic(
        magneticHeading: 100,
        declination: -7,
      ),
      closeTo(93, .0001),
    );
  });
}

PrayerLocation _location() {
  return const PrayerLocation(
    latitude: 24.8607,
    longitude: 67.0011,
    city: 'Karachi',
    region: 'Sindh',
    country: 'Pakistan',
    countryCode: 'PK',
    timezoneId: 'Asia/Karachi',
    source: PrayerLocationSource.city,
  );
}

class _NoSensorCompassService implements CompassService {
  @override
  Future<bool> hasSensors() async => false;

  @override
  Stream<CompassReading> readings() =>
      const Stream<CompassReading>.empty();
}

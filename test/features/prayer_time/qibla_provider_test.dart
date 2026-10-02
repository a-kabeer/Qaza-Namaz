import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/features/prayer_time/application/prayer_time_providers.dart';
import 'package:qaza_namaz/features/prayer_time/application/qibla_providers.dart';
import 'package:qaza_namaz/features/prayer_time/data/device_compass_service.dart';
import 'package:qaza_namaz/features/prayer_time/domain/prayer_location.dart';
import 'package:qaza_namaz/features/prayer_time/domain/prayer_settings.dart';
import 'package:qaza_namaz/features/prayer_time/domain/prayer_time.dart';
import 'package:qaza_namaz/features/prayer_time/domain/qibla_direction_service.dart';

void main() {
  test('qibla bearing provider uses the saved Prayer Location', () async {
    final snapshot = _snapshot();
    final container = ProviderContainer(
      overrides: [
        prayerTimeControllerProvider.overrideWith(
          () => _FakePrayerTimeController(snapshot),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(prayerTimeControllerProvider.future);

    expect(
      container.read(qiblaBearingProvider),
      closeTo(267.741, .01),
    );
  });

  test('sensor unavailable state is supported without disabling static Qibla', () async {
    final container = ProviderContainer(
      overrides: [
        compassServiceProvider.overrideWithValue(_NoSensorCompassService()),
      ],
    );
    addTearDown(container.dispose);

    final available = await container.read(
      compassSensorAvailableProvider.future,
    );

    expect(available, isFalse);
  });

  test('true heading conversion uses the local declination sign convention', () {
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

PrayerTimeSnapshot _snapshot() {
  final location = PrayerLocation(
    latitude: 24.8607,
    longitude: 67.0011,
    city: 'Karachi',
    region: 'Sindh',
    country: 'Pakistan',
    countryCode: 'PK',
    timezoneId: 'Asia/Karachi',
    source: PrayerLocationSource.city,
  );
  final date = DateTime(2026, 10, 2);
  final times = {
    for (final slot in PrayerSlot.values)
      slot: DateTime.utc(2026, 10, 2, 6 + slot.index),
  };
  final schedule = PrayerSchedule(
    date: date,
    timesUtc: times,
    astronomicalSunriseUtc: DateTime.utc(2026, 10, 2, 6),
    astronomicalDhuhrUtc: DateTime.utc(2026, 10, 2, 12),
    astronomicalSunsetUtc: DateTime.utc(2026, 10, 2, 18),
  );

  return PrayerTimeSnapshot(
    location: location,
    settings: const PrayerSettings(),
    today: schedule,
    tomorrow: PrayerSchedule(
      date: date.add(const Duration(days: 1)),
      timesUtc: {
        for (final slot in PrayerSlot.values)
          slot: DateTime.utc(2026, 10, 3, 6 + slot.index),
      },
      astronomicalSunriseUtc: DateTime.utc(2026, 10, 3, 6),
      astronomicalDhuhrUtc: DateTime.utc(2026, 10, 3, 12),
      astronomicalSunsetUtc: DateTime.utc(2026, 10, 3, 18),
    ),
    updatedAt: DateTime.utc(2026, 10, 2),
  );
}

class _FakePrayerTimeController
    extends AsyncNotifier<PrayerTimeSnapshot?> {
  _FakePrayerTimeController(this.value);

  final PrayerTimeSnapshot value;

  @override
  FutureOr<PrayerTimeSnapshot?> build() async => value;
}

class _NoSensorCompassService implements CompassService {
  @override
  Future<bool> hasSensors() async => false;

  @override
  Stream<CompassReading> readings() => const Stream<CompassReading>.empty();
}

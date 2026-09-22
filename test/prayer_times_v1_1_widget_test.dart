import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../lib/features/prayer_times/data/location/city_search_provider.dart';
import '../lib/features/prayer_times/data/location/prayer_location_service.dart';
import '../lib/features/prayer_times/domain/prayer_times_models.dart';
import '../lib/features/prayer_times/domain/prayer_times_repository.dart';
import '../lib/features/prayer_times/prayer_times_providers.dart';
import '../lib/features/prayer_times/presentation/prayer_times_screen.dart';

class _Repo implements PrayerTimesRepository {
  PrayerLocation? location = const PrayerLocation(
    latitude: 24.8607,
    longitude: 67.0011,
    city: 'Karachi',
    country: 'Pakistan',
    countryCode: 'PK',
    timezone: 'Asia/Karachi',
    source: LocationSource.manualCity,
  );

  @override
  Future<PrayerDay> getPrayerTimes({
    required double latitude,
    required double longitude,
    required DateTime date,
    required CalculationMethod method,
    required AsrMethod asrMethod,
    String? timezone,
  }) async =>
      PrayerDay(
        date: date,
        timezone: 'Asia/Karachi',
        times: const {
          PrayerName.fajr: PrayerTime(hour: 4, minute: 50),
          PrayerName.sunrise: PrayerTime(hour: 6, minute: 8),
          PrayerName.dhuhr: PrayerTime(hour: 12, minute: 20),
          PrayerName.asr: PrayerTime(hour: 16, minute: 45),
          PrayerName.maghrib: PrayerTime(hour: 18, minute: 28),
          PrayerName.isha: PrayerTime(hour: 19, minute: 44),
        },
        solarNoon: DateTime(2026, 9, 20, 12, 20),
        sunset: DateTime(2026, 9, 20, 18, 28),
        hijriDate: const HijriDate(day: 18, month: 'Rabi al-Thani', year: 1448),
        fetchedAt: DateTime.utc(2026, 9, 20),
      );

  @override
  Future<PrayerLocation?> getSavedLocation() async => location;

  @override
  Future<void> saveLocation(PrayerLocation value) async {
    location = value;
  }

  @override
  Future<PrayerSettings> getSavedSettings() async => const PrayerSettings();

  @override
  Future<void> saveSettings(PrayerSettings value) async {}
}

class _Location implements PrayerLocationService {
  @override
  Future<PrayerLocation> getCurrentLocation({String? locale}) async =>
      throw const PrayerLocationException(
        PrayerLocationErrorKind.positionUnavailable,
        'Unavailable',
      );

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}

class _Cities implements CitySearchProvider {
  @override
  Future<List<CitySearchResult>> search(String query) async => const [];

  @override
  Future<List<CitySearchResult>> searchInCountry(
    String query, {
    String? countryCode,
  }) async =>
      const [];
}

class _FixedClock implements PrayerTimesClock {
  const _FixedClock(this.value);
  final DateTime value;

  @override
  DateTime now() => value;
}

ProviderContainer _container() => ProviderContainer(
      overrides: [
        prayerTimesRepositoryProvider.overrideWithValue(_Repo()),
        prayerTimesClockProvider.overrideWithValue(
          _FixedClock(DateTime(2026, 9, 20, 12)),
        ),
        prayerLocationServiceProvider.overrideWithValue(_Location()),
        prayerCitySearchProvider.overrideWithValue(_Cities()),
      ],
    );

void main() {
  testWidgets(
    'renders local calculated prayer data without network UI',
    (tester) async {
      final container = _container();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: const PrayerTimesScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Fajr'), findsOneWidget);
      expect(find.text('4:50 AM'), findsOneWidget);
      expect(find.text('Prayer times could not be calculated'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

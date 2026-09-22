import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../lib/features/prayer_times/data/location/city_search_provider.dart';
import '../lib/features/prayer_times/data/location/prayer_location_service.dart';
import '../lib/features/prayer_times/domain/prayer_times_models.dart';
import '../lib/features/prayer_times/domain/prayer_times_repository.dart';
import '../lib/features/prayer_times/presentation/prayer_times_controller.dart';
import '../lib/features/prayer_times/prayer_times_providers.dart';

class _FakeRepository implements PrayerTimesRepository {
  PrayerLocation? location;
  PrayerSettings settings = const PrayerSettings();
  int fetchCount = 0;
  Object? fetchError;

  PrayerDay _day(DateTime date) => PrayerDay(
        date: date,
        timezone: location?.timezone ?? 'Asia/Karachi',
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
        hijriDate: HijriDate(day: 18, month: 'Rabi al-Thani', year: 1448),
        fetchedAt: DateTime.utc(2026, 9, 20),
      );

  @override
  Future<PrayerDay> getPrayerTimes({
    required double latitude,
    required double longitude,
    required DateTime date,
    required CalculationMethod method,
    required AsrMethod asrMethod,
    String? timezone,
  }) async {
    fetchCount++;
    final error = fetchError;
    if (error != null) throw error;
    return _day(date);
  }

  @override
  Future<PrayerLocation?> getSavedLocation() async => location;

  @override
  Future<void> saveLocation(PrayerLocation value) async {
    location = value;
  }

  @override
  Future<PrayerSettings> getSavedSettings() async => settings;

  @override
  Future<void> saveSettings(PrayerSettings value) async {
    settings = value;
  }
}

class _FakeLocationService implements PrayerLocationService {
  PrayerLocation? location;
  PrayerLocationException? failure;

  @override
  Future<PrayerLocation> getCurrentLocation({String? locale}) async {
    final error = failure;
    if (error != null) throw error;
    return location!;
  }

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}

class _FakeCitySearchProvider implements CitySearchProvider {
  @override
  Future<List<CitySearchResult>> search(String query) async => const [
        CitySearchResult(
          name: 'Karachi',
          country: 'Pakistan',
          countryCode: 'PK',
          latitude: 24.8607,
          longitude: 67.0011,
          region: 'Sindh',
          timezone: 'Asia/Karachi',
        ),
      ];
}

class _FixedClock implements PrayerTimesClock {
  const _FixedClock(this.value);
  final DateTime value;

  @override
  DateTime now() => value;
}

void main() {
  ProviderContainer containerFor({
    required _FakeRepository repository,
    required DateTime now,
    _FakeLocationService? locationService,
  }) {
    return ProviderContainer(
      overrides: [
        prayerTimesRepositoryProvider.overrideWithValue(repository),
        prayerTimesClockProvider.overrideWithValue(_FixedClock(now)),
        prayerLocationServiceProvider.overrideWithValue(
          locationService ?? _FakeLocationService(),
        ),
        prayerCitySearchProvider.overrideWithValue(_FakeCitySearchProvider()),
      ],
    );
  }

  test('loads prayer times locally without cache dependency', () async {
    final repository = _FakeRepository()
      ..location = const PrayerLocation(
        latitude: 24.8607,
        longitude: 67.0011,
        city: 'Karachi',
        country: 'Pakistan',
        countryCode: 'PK',
        timezone: 'Asia/Karachi',
        source: LocationSource.manualCity,
      );
    final container = containerFor(
      repository: repository,
      now: DateTime(2026, 9, 20, 12),
    );
    addTearDown(container.dispose);

    await container.read(prayerTimesControllerProvider.notifier).refresh();

    final state = container.read(prayerTimesControllerProvider);
    expect(state.status, PrayerTimesStatus.loaded);
    expect(state.today, isNotNull);
    expect(repository.fetchCount, greaterThanOrEqualTo(1));
  });

  test('useMyLocation persists device location and loads prayer times', () async {
    final repository = _FakeRepository();
    final locationService = _FakeLocationService()
      ..location = const PrayerLocation(
        latitude: 24.8607,
        longitude: 67.0011,
        city: 'Karachi',
        country: 'Pakistan',
        countryCode: 'PK',
        timezone: 'Asia/Karachi',
        source: LocationSource.device,
      );
    final container = containerFor(
      repository: repository,
      now: DateTime(2026, 9, 20, 12),
      locationService: locationService,
    );
    addTearDown(container.dispose);

    await container.read(prayerTimesControllerProvider.notifier).useMyLocation();

    final state = container.read(prayerTimesControllerProvider);
    expect(state.status, PrayerTimesStatus.loaded);
    expect(state.location?.source, LocationSource.device);
  });

  test('permanently denied location remains distinct', () async {
    final repository = _FakeRepository();
    final locationService = _FakeLocationService()
      ..failure = const PrayerLocationException(
        PrayerLocationErrorKind.permissionPermanentlyDenied,
        'Permission permanently denied.',
      );
    final container = containerFor(
      repository: repository,
      now: DateTime(2026, 9, 20, 12),
      locationService: locationService,
    );
    addTearDown(container.dispose);

    await container.read(prayerTimesControllerProvider.notifier).useMyLocation();

    expect(
      container.read(prayerTimesControllerProvider).locationErrorKind,
      PrayerLocationErrorKind.permissionPermanentlyDenied,
    );
  });

  test('city search works without a network provider', () async {
    final container = containerFor(
      repository: _FakeRepository(),
      now: DateTime(2026, 9, 20, 12),
    );
    addTearDown(container.dispose);

    final controller = container.read(prayerTimesControllerProvider.notifier);
    controller.searchCities('Karachi');

    await Future<void>.delayed(const Duration(milliseconds: 260));

    final state = container.read(prayerTimesControllerProvider);
    expect(state.cityResults, hasLength(1));
    expect(state.cityResults.single.countryCode, 'PK');
  });
}

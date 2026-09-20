import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../lib/features/prayer_times/data/location/city_search_provider.dart';
import '../lib/features/prayer_times/data/location/prayer_location_service.dart';
import '../lib/features/prayer_times/domain/prayer_times_models.dart';
import '../lib/features/prayer_times/domain/prayer_times_repository.dart';
import '../lib/features/prayer_times/presentation/prayer_times_controller.dart';
import '../lib/features/prayer_times/prayer_times_providers.dart';

class _FixedClock implements PrayerTimesClock {
  const _FixedClock(this.value);

  final DateTime value;

  @override
  DateTime now() => value;
}

class _Repository implements PrayerTimesRepository {
  PrayerLocation? location;
  PrayerSettings settings = const PrayerSettings();
  final List<DateTime> requestedDates = <DateTime>[];
  Object? fetchError;

  PrayerDay _day(DateTime date, String timezone) => PrayerDay(
        date: date,
        timezone: timezone,
        times: const {
          PrayerName.fajr: PrayerTime(hour: 4, minute: 50),
          PrayerName.sunrise: PrayerTime(hour: 6, minute: 8),
          PrayerName.dhuhr: PrayerTime(hour: 12, minute: 20),
          PrayerName.asr: PrayerTime(hour: 16, minute: 45),
          PrayerName.maghrib: PrayerTime(hour: 18, minute: 28),
          PrayerName.isha: PrayerTime(hour: 19, minute: 44),
        },
        hijriDate: HijriDate(
          day: 18,
          month: 'Rabi al-Thani',
          year: 1448,
        ),
        fetchedAt: DateTime.utc(2026, 9, 20),
      );

  @override
  Future<PrayerDay?> getCachedPrayerTimes(PrayerTimesRequest request) async => null;

  @override
  Future<PrayerDay> getPrayerTimes({
    required double latitude,
    required double longitude,
    required DateTime date,
    required CalculationMethod method,
    required AsrMethod asrMethod,
  }) async {
    requestedDates.add(date);
    final error = fetchError;
    if (error != null) throw error;
    return _day(date, 'America/Los_Angeles');
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

class _LocationService implements PrayerLocationService {
  const _LocationService(this.failure);

  final PrayerLocationException? failure;

  @override
  Future<PrayerLocation> getCurrentLocation({String? locale}) async {
    throw failure ??
        const PrayerLocationException(
          PrayerLocationErrorKind.positionUnavailable,
          'Unavailable',
        );
  }

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}

class _CitySearch implements CitySearchProvider {
  const _CitySearch();

  @override
  Future<List<CitySearchResult>> search(String query) async => const [];
}

ProviderContainer _container({
  required _Repository repository,
  required DateTime now,
  PrayerLocationException? locationFailure,
}) {
  return ProviderContainer(
    overrides: [
      prayerTimesRepositoryProvider.overrideWithValue(repository),
      prayerTimesClockProvider.overrideWithValue(_FixedClock(now)),
      prayerLocationServiceProvider.overrideWithValue(
        _LocationService(locationFailure),
      ),
      prayerCitySearchProvider.overrideWithValue(const _CitySearch()),
    ],
  );
}

void main() {
  test('manual coordinates correct the date after timezone resolution', () async {
    final repository = _Repository();
    final container = _container(
      repository: repository,
      now: DateTime.utc(2026, 9, 21, 1),
    );
    addTearDown(container.dispose);

    final controller =
        container.read(prayerTimesControllerProvider.notifier);

    await controller.useManualCoordinates('34.0522', '-118.2437');

    expect(repository.requestedDates, [
      DateTime(2026, 9, 21),
      DateTime(2026, 9, 20),
    ]);

    final state = container.read(prayerTimesControllerProvider);
    expect(state.location?.timezone, 'America/Los_Angeles');
    expect(state.today?.date, DateTime(2026, 9, 20));
  });

  test('service-disabled location becomes actionable error', () async {
    final repository = _Repository();
    final container = _container(
      repository: repository,
      now: DateTime.utc(2026, 9, 20, 12),
      locationFailure: const PrayerLocationException(
        PrayerLocationErrorKind.serviceDisabled,
        'Location services are turned off.',
      ),
    );
    addTearDown(container.dispose);

    await container
        .read(prayerTimesControllerProvider.notifier)
        .useMyLocation();

    final state = container.read(prayerTimesControllerProvider);
    expect(state.status, PrayerTimesStatus.locationError);
    expect(
      state.locationErrorKind,
      PrayerLocationErrorKind.serviceDisabled,
    );
  });

  test('permission-denied location becomes actionable error', () async {
    final repository = _Repository();
    final container = _container(
      repository: repository,
      now: DateTime.utc(2026, 9, 20, 12),
      locationFailure: const PrayerLocationException(
        PrayerLocationErrorKind.permissionDenied,
        'Location permission was denied.',
      ),
    );
    addTearDown(container.dispose);

    await container
        .read(prayerTimesControllerProvider.notifier)
        .useMyLocation();

    final state = container.read(prayerTimesControllerProvider);
    expect(state.locationErrorKind, PrayerLocationErrorKind.permissionDenied);
  });

  test('permanent permission denial remains distinct', () async {
    final repository = _Repository();
    final container = _container(
      repository: repository,
      now: DateTime.utc(2026, 9, 20, 12),
      locationFailure: const PrayerLocationException(
        PrayerLocationErrorKind.permissionPermanentlyDenied,
        'Permission permanently denied.',
      ),
    );
    addTearDown(container.dispose);

    await container
        .read(prayerTimesControllerProvider.notifier)
        .useMyLocation();

    final state = container.read(prayerTimesControllerProvider);
    expect(
      state.locationErrorKind,
      PrayerLocationErrorKind.permissionPermanentlyDenied,
    );
  });
}

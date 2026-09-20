import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../lib/features/prayer_times/data/location/city_search_provider.dart';
import '../lib/features/prayer_times/data/location/prayer_location_service.dart';
import '../lib/features/prayer_times/data/prayer_times_provider.dart';
import '../lib/features/prayer_times/domain/prayer_times_models.dart';
import '../lib/features/prayer_times/domain/prayer_times_repository.dart';
import '../lib/features/prayer_times/presentation/prayer_times_screen.dart';
import '../lib/features/prayer_times/prayer_times_providers.dart';
import '../lib/core/widgets/skeleton.dart';

class _Repo implements PrayerTimesRepository {
  _Repo({this.delay = Duration.zero, this.fail = false});

  final Duration delay;
  final bool fail;
  PrayerLocation? location = const PrayerLocation(
    latitude: 24.8607,
    longitude: 67.0011,
    city: 'Karachi',
    country: 'Pakistan',
    countryCode: 'PK',
    timezone: 'Asia/Karachi',
    source: LocationSource.manualCity,
  );

  final PrayerSettings settings = const PrayerSettings();

  PrayerDay get day => PrayerDay(
        date: DateTime(2026, 9, 20),
        timezone: 'Asia/Karachi',
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
  Future<PrayerDay?> getCachedPrayerTimes(PrayerTimesRequest request) async =>
      null;

  @override
  Future<PrayerDay> getPrayerTimes({
    required double latitude,
    required double longitude,
    required DateTime date,
    required CalculationMethod method,
    required AsrMethod asrMethod,
  }) async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    if (fail) {
      throw const PrayerApiException('simulated failure');
    }
    return day;
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
  Future<void> saveSettings(PrayerSettings value) async {}
}

class _Location implements PrayerLocationService {
  @override
  Future<PrayerLocation> getCurrentLocation({String? locale}) async {
    throw const PrayerLocationException(
      PrayerLocationErrorKind.positionUnavailable,
      'Unavailable',
    );
  }

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}

class _Cities implements CitySearchProvider {
  @override
  Future<List<CitySearchResult>> search(String query) async => const [];
}

class _Provider implements PrayerTimesProvider {
  @override
  Future<PrayerDay> fetch(PrayerTimesRequest request) async {
    throw UnimplementedError();
  }
}

ProviderContainer _container(_Repo repo) {
  return ProviderContainer(
    overrides: [
      prayerTimesRepositoryProvider.overrideWithValue(repo),
      prayerTimesClockProvider.overrideWithValue(
        _FixedClock(DateTime(2026, 9, 20, 12)),
      ),
      prayerLocationServiceProvider.overrideWithValue(_Location()),
      prayerCitySearchProvider.overrideWithValue(_Cities()),
      prayerTimesProvider.overrideWithValue(_Provider()),
    ],
  );
}

class _FixedClock implements PrayerTimesClock {
  const _FixedClock(this.value);
  final DateTime value;

  @override
  DateTime now() => value;
}

Widget _app({required Widget child, Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      DefaultMaterialLocalizations.delegate,
      DefaultWidgetsLocalizations.delegate,
      DefaultCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [
      Locale('en'),
      Locale('ur'),
    ],
    theme: ThemeData.light(),
    home: child,
  );
}

void main() {
  testWidgets('shows skeleton while prayer times are loading', (tester) async {
    final repo = _Repo(delay: const Duration(milliseconds: 250));
    final container = _container(repo);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _app(child: const PrayerTimesScreen()),
      ),
    );
    await tester.pump();

    expect(find.byType(SkeletonShimmer), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(find.text('Fajr'), findsOneWidget);
    expect(find.text('04:50'), findsOneWidget);
  });

  testWidgets('shows actionable API error state', (tester) async {
    final repo = _Repo(fail: true);
    final container = _container(repo);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _app(child: const PrayerTimesScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.textContaining('Prayer times could not be loaded'),
      findsOneWidget,
    );
    expect(find.text('Try Again'), findsOneWidget);
    expect(find.text('Choose Location Manually'), findsOneWidget);
  });

  testWidgets('renders Urdu, dark theme and narrow layout without exceptions',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;

    final repo = _Repo();
    final container = _container(repo);
    addTearDown(() {
      container.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('ur'),
          localizationsDelegates: const [
            DefaultMaterialLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
            DefaultCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('ur')],
          theme: ThemeData.dark(),
          home: const PrayerTimesScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('نماز کے اوقات'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

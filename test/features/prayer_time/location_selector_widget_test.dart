import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

import 'package:qaza_namaz/features/prayer_time/application/prayer_time_controller.dart';
import 'package:qaza_namaz/features/prayer_time/application/prayer_time_providers.dart';
import 'package:qaza_namaz/features/prayer_time/data/offline_city_resolver.dart';
import 'package:qaza_namaz/features/prayer_time/data/prayer_location_repository.dart';
import 'package:qaza_namaz/features/prayer_time/domain/prayer_location.dart';
import 'package:qaza_namaz/features/prayer_time/domain/prayer_time.dart';
import 'package:qaza_namaz/features/prayer_time/presentation/location_selector.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(tzdata.initializeTimeZones);

  testWidgets(
    'selects Pakistan to Karachi end-to-end and preserves location data',
    (tester) async {
      final fakeController = _FakePrayerTimeController();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            prayerTimeControllerProvider.overrideWith(() => fakeController),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: LocationSelector(location: null),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('prayer_time_location_selector')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('prayer_time_location_selector')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final countrySearch = find.byKey(
        const Key('prayer_time_country_search'),
      );
      expect(countrySearch, findsOneWidget);
      expect(find.byType(ListTile), findsWidgets);
      await tester.enterText(countrySearch, 'Pakistan');
      await tester.pump();

      final pakistan = find.byKey(const Key('prayer_time_country_PK'));
      expect(pakistan, findsOneWidget);
      await tester.tap(pakistan);
      await tester.pump();

      expect(find.byKey(const Key('prayer_time_city_search')), findsOneWidget);
      expect(find.text('Karachi'), findsAtLeastNWidgets(1));

      await tester.enterText(
        find.byKey(const Key('prayer_time_city_search')),
        ' Karachi ',
      );
      await tester.pump();

      expect(find.text('Karachi'), findsAtLeastNWidgets(1));
      expect(find.text('Lahore'), findsNothing);

      await tester.tap(find.text('Karachi').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final selectedCity = fakeController.selectedCity;
      expect(selectedCity, isNotNull);
      expect(selectedCity!.city, 'Karachi');
      expect(selectedCity.countryCode, 'PK');
      expect(selectedCity.timezoneId, 'Asia/Karachi');
      expect(selectedCity.latitude.isFinite, isTrue);
      expect(selectedCity.longitude.isFinite, isTrue);

      final location = PrayerLocationRepository(
        OfflineCityResolver(),
      ).fromCity(selectedCity);
      expect(location.city, 'Karachi');
      expect(location.countryCode, 'PK');
      expect(location.timezoneId, 'Asia/Karachi');
      expect(location.latitude, selectedCity.latitude);
      expect(location.longitude, selectedCity.longitude);
    },
  );

  testWidgets(
    'clears city search when returning to countries and allows Japan to Tokyo',
    (tester) async {
      final fakeController = _FakePrayerTimeController();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            prayerTimeControllerProvider.overrideWith(() => fakeController),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: LocationSelector(location: null),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('prayer_time_location_selector')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final countrySearch = find.byKey(
        const Key('prayer_time_country_search'),
      );
      expect(countrySearch, findsOneWidget);
      await tester.enterText(countrySearch, 'Pakistan');
      await tester.pump();

      final pakistan = find.byKey(const Key('prayer_time_country_PK'));
      expect(pakistan, findsOneWidget);
      await tester.tap(pakistan);
      await tester.pump();

      final citySearch = find.byKey(const Key('prayer_time_city_search'));
      await tester.enterText(citySearch, 'Karachi');
      await tester.pump();

      await tester.tap(find.byTooltip('Back'));
      await tester.pump();

      final countrySearch = find.byKey(
        const Key('prayer_time_country_search'),
      );
      expect(countrySearch, findsOneWidget);
      final searchBar = tester.widget<SearchBar>(countrySearch);
      expect(searchBar.controller?.text, isEmpty);

      await tester.enterText(countrySearch, 'Japan');
      await tester.pump();

      final japan = find.byKey(const Key('prayer_time_country_JP'));
      expect(japan, findsOneWidget);
      await tester.tap(japan);
      await tester.pump();

      expect(find.byKey(const Key('prayer_time_city_search')), findsOneWidget);
      expect(find.text('Tokyo'), findsAtLeastNWidgets(1));
      expect(find.text('Karachi'), findsNothing);
    },
  );
}

class _FakePrayerTimeController extends PrayerTimeController {
  CityOption? selectedCity;

  @override
  Future<PrayerTimeSnapshot?> build() async => null;

  @override
  Future<bool> selectCity(CityOption city) async {
    selectedCity = city;
    return true;
  }
}

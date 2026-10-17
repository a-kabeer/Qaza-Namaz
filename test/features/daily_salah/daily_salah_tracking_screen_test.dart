import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/data/local/drift_qaza_local_store.dart';
import 'package:qaza_namaz/data/repositories/offline_first_qaza_repository.dart';
import 'package:qaza_namaz/domain/services/qaza_service.dart';
import 'package:qaza_namaz/features/daily_salah/daily_salah_tracking_screen.dart';
import 'package:qaza_namaz/features/daily_salah/daily_salah_tracking_providers.dart';
import 'package:qaza_namaz/features/daily_salah/daily_salah_tracking_service.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

void main() {
  late AppDatabase database;
  late OfflineFirstQazaRepository repository;
  late QazaService qazaService;
  late DailySalahTrackingService tracking;
  const userId = 'daily-salah-widget-test-user';

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    await database.customSelect('SELECT 1').get();
    repository = OfflineFirstQazaRepository(
      localStore: DriftQazaLocalStore(database: database),
    );
    await repository.setActiveUser(userId);
    qazaService = QazaService(repository);
    tracking = DailySalahTrackingService(
      database: database,
      qazaService: qazaService,
    );
    await tracking.setEnabled(true);
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets('Prayed can be selected and toggled back to Unrecorded',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          qazaServiceProvider.overrideWithValue(qazaService),
          activeUserIdProvider.overrideWithValue(userId),
          dailySalahTrackingDateProvider.overrideWith((ref) => _today()),
          effectiveWitrProvider.overrideWithValue(true),
          dailySalahPrayerAvailableProvider
              .overrideWith((ref, request) => true),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DailySalahTrackingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final prayedButton = find.byKey(const Key('daily_salah_prayed_fajr'));
    expect(prayedButton, findsOneWidget);

    await tester.tap(prayedButton);
    await tester.pumpAndSettle();
    expect(
      (await tracking.logForDate(
        userId: userId,
        date: DateTime.now(),
        prayerType: PrayerType.fajr,
      ))
          ?.status,
      DailySalahStatus.prayed,
    );

    await tester.tap(prayedButton);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('daily_salah_confirm_remove_status')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('daily_salah_confirm_remove_status')),
    );
    await tester.pumpAndSettle();
    expect(
      (await tracking.logForDate(
        userId: userId,
        date: DateTime.now(),
        prayerType: PrayerType.fajr,
      ))
          ?.status,
      DailySalahStatus.unrecorded,
    );
  });

  testWidgets('Missed asks for confirmation before creating a Qaza entry',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          qazaServiceProvider.overrideWithValue(qazaService),
          activeUserIdProvider.overrideWithValue(userId),
          dailySalahTrackingDateProvider.overrideWith((ref) => _today()),
          effectiveWitrProvider.overrideWithValue(true),
          dailySalahPrayerAvailableProvider
              .overrideWith((ref, request) => true),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DailySalahTrackingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('daily_salah_missed_fajr')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('daily_salah_confirm_missed')), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    var page = await qazaService.getPage(
      userId: userId,
      prayerType: PrayerType.fajr,
      from: normalizedToday,
      to: normalizedToday,
      status: null,
    );
    expect(page.records, isEmpty);

    await tester.tap(find.byKey(const Key('daily_salah_missed_fajr')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('daily_salah_confirm_missed')));
    await tester.pumpAndSettle();

    page = await qazaService.getPage(
      userId: userId,
      prayerType: PrayerType.fajr,
      from: normalizedToday,
      to: normalizedToday,
      status: null,
    );
    expect(page.records, hasLength(1));

    // Removing the tracking status must not delete the Qaza record.
    await tester.tap(find.byKey(const Key('daily_salah_missed_fajr')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('daily_salah_confirm_remove_status')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('daily_salah_confirm_remove_status')),
    );
    await tester.pumpAndSettle();
    final stillExists = await qazaService.getPage(
      userId: userId,
      prayerType: PrayerType.fajr,
      from: normalizedToday,
      to: normalizedToday,
      status: null,
    );
    expect(stillExists.records, hasLength(1));
    expect(
      (await tracking.logForDate(
        userId: userId,
        date: normalizedToday,
        prayerType: PrayerType.fajr,
      ))
          ?.status,
      DailySalahStatus.unrecorded,
    );
  });

  testWidgets('calendar moves dates with horizontal swipes', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          qazaServiceProvider.overrideWithValue(qazaService),
          activeUserIdProvider.overrideWithValue(userId),
          dailySalahTrackingDateProvider.overrideWith((ref) => _today()),
          effectiveWitrProvider.overrideWithValue(true),
          dailySalahPrayerAvailableProvider
              .overrideWith((ref, request) => true),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DailySalahTrackingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final label = find.byKey(const Key('daily_salah_selected_date'));
    final currentDate = tester.widget<Text>(label).data;
    await tester.drag(
      find.byKey(const Key('daily_salah_calendar_swipe')),
      const Offset(180, 0),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(label).data, isNot(currentDate));

    await tester.drag(
      find.byKey(const Key('daily_salah_calendar_swipe')),
      const Offset(-180, 0),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(label).data, currentDate);
  });
}

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

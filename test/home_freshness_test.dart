import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/core/theme/app_theme.dart';
import 'package:qaza_namaz/domain/entities/app_user.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/services/sahib_al_tartib_service.dart';
import 'package:qaza_namaz/features/home/home_screen.dart';
import 'package:qaza_namaz/features/home/home_state.dart';
import 'package:qaza_namaz/features/home/providers/home_providers.dart';
import 'package:qaza_namaz/features/prayer_times/prayer_times_providers.dart';

import 'support/in_memory_qaza_repository.dart';
import 'support/test_app.dart';

/// A clock the test moves by hand.
class _FakeClock implements PrayerTimesClock {
  _FakeClock(this._now);
  DateTime _now;

  void set(DateTime value) => _now = value;

  @override
  DateTime now() => _now;
}

/// Home must stay current: across midnight, and across a resume.
void main() {
  final stamp = DateTime(2026, 9, 22);

  QazaRecord record(String id, PrayerType prayer, int day, QazaStatus status) =>
      QazaRecord(
        id: id,
        userId: 'u1',
        prayerType: prayer,
        originalDate: DateTime(2026, 1, day),
        status: status,
        completedAt: status == QazaStatus.completed ? stamp : null,
        createdAt: stamp,
        updatedAt: stamp,
      );

  Future<InMemoryQazaRepository> ledger() async {
    final repository = InMemoryQazaRepository();
    await repository.addRecords([
      record('f1', PrayerType.fajr, 1, QazaStatus.pending),
      record('f2', PrayerType.fajr, 2, QazaStatus.completed),
      record('z1', PrayerType.zuhr, 4, QazaStatus.pending),
    ]);
    return repository;
  }

  /// Pumps Home with a controllable clock and, optionally, a stalled or
  /// failed Sahib al-Tartib lookup.
  Future<ProviderContainer> pumpHome(
    WidgetTester tester, {
    required _FakeClock clock,
    Locale locale = const Locale('en'),
    Override? tartib,
  }) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    final container = ProviderContainer(overrides: [
      qazaRepositoryProvider.overrideWithValue(await ledger()),
      activeUserIdProvider.overrideWithValue('u1'),
      prayerTimesClockProvider.overrideWithValue(clock),
      authStateProvider.overrideWith(
        (ref) => Stream.value(const AppUser(id: 'u1', email: 'u1@e.com')),
      ),
      if (tartib != null) tartib,
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: TestApp(
        theme: AppTheme.light(locale: locale),
        locale: locale,
        home: const HomeScreen(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    return container;
  }

  String dateText(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('home_today_date'))).data!;

  group('the day turning', () {
    testWidgets('Home left open across midnight moves to the new day',
        (tester) async {
      final clock = _FakeClock(DateTime(2026, 9, 22, 23, 59, 30));
      final container = await pumpHome(tester, clock: clock);

      final before = container.read(homeLocalDateProvider);
      expect(before, DateTime(2026, 9, 22));
      final shownBefore = dateText(tester);

      // The clock rolls over while the screen just sits there.
      clock.set(DateTime(2026, 9, 23, 0, 0, 5));
      await tester.pump(const Duration(seconds: 40));
      await tester.pump(const Duration(milliseconds: 400));

      expect(container.read(homeLocalDateProvider), DateTime(2026, 9, 23),
          reason: 'the local date must follow the clock past midnight');
      expect(dateText(tester), isNot(shownBefore),
          reason: 'and the date on screen must say so');
    });

    testWidgets('nothing is rebuilt while the day has not turned',
        (tester) async {
      final clock = _FakeClock(DateTime(2026, 9, 22, 10, 0));
      final container = await pumpHome(tester, clock: clock);
      final shown = dateText(tester);

      // Time passes, but not past midnight.
      clock.set(DateTime(2026, 9, 22, 14, 30));
      await tester.pump(const Duration(minutes: 1));

      expect(container.read(homeLocalDateProvider), DateTime(2026, 9, 22));
      expect(dateText(tester), shown);
    });

    testWidgets('resuming on a new local day refreshes the dashboard',
        (tester) async {
      final clock = _FakeClock(DateTime(2026, 9, 22, 22, 0));
      final container = await pumpHome(tester, clock: clock);
      expect(container.read(homeLocalDateProvider), DateTime(2026, 9, 22));

      // Backgrounded overnight, resumed the next morning.
      clock.set(DateTime(2026, 9, 24, 8, 0));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(container.read(homeLocalDateProvider), DateTime(2026, 9, 24),
          reason:
              'a resume must re-read the local date, not trust the old one');
    });
  });

  group('Sahib al-Tartib gating', () {
    Override stalled() => sahibAlTartibProvider.overrideWith(
          (ref) => Completer<SahibAlTartibState>().future,
        );

    Override failed() => sahibAlTartibProvider.overrideWith(
          (ref) => Future<SahibAlTartibState>.error(
            StateError('tartib lookup failed'),
          ),
        );

    testWidgets('no Fard action is offered while the order is still loading',
        (tester) async {
      final clock = _FakeClock(DateTime(2026, 9, 22, 10, 0));
      final container = await pumpHome(tester, clock: clock, tartib: stalled());

      expect(
        container.read(homeSelectedPrayerProvider).source,
        HomePrayerSelectionSource.tartibUnavailable,
      );
      expect(container.read(homeSelectedPrayerProvider).prayer, isNull,
          reason: 'automatic selection must not pick a Fard prayer yet');
      expect(find.byKey(const Key('home_tartib_unavailable')), findsOneWidget);
      // Still loading, so there is nothing to retry.
      expect(find.byKey(const Key('home_tartib_retry')), findsNothing);
    });

    testWidgets('a failed order check explains itself and offers a retry',
        (tester) async {
      final clock = _FakeClock(DateTime(2026, 9, 22, 10, 0));
      final container = await pumpHome(tester, clock: clock, tartib: failed());

      expect(
        container.read(homeSelectedPrayerProvider).source,
        HomePrayerSelectionSource.tartibUnavailable,
      );
      expect(find.byKey(const Key('home_tartib_unavailable')), findsOneWidget);
      expect(find.byKey(const Key('home_tartib_retry')), findsOneWidget);
    });

    testWidgets('automatic and manual agree while the order is unknown',
        (tester) async {
      final clock = _FakeClock(DateTime(2026, 9, 22, 10, 0));
      final container = await pumpHome(tester, clock: clock, tartib: failed());

      // The defect this covers: manual selection refused a Fard prayer in
      // this state while automatic selection quietly offered one.
      final selected = container.read(homeSelectedPrayerProvider);
      expect(selected.prayer, isNull);
      expect(selected.mode, HomePrayerSelectionMode.automatic);
      // And no oldest-pending Fard card is standing in for it.
      expect(find.byKey(const Key('home_oldest_qaza_date')), findsNothing);
    });

    testWidgets('an order that does not apply lets the current prayer through',
        (tester) async {
      final clock = _FakeClock(DateTime(2026, 9, 22, 10, 0));
      final container = await pumpHome(
        tester,
        clock: clock,
        tartib: sahibAlTartibProvider.overrideWith(
          (ref) async => const SahibAlTartibState(
            pendingFarzCount: 0,
            requiresOrder: false,
            nextPending: null,
          ),
        ),
      );

      final selected = container.read(homeSelectedPrayerProvider);
      expect(
          selected.source, isNot(HomePrayerSelectionSource.tartibUnavailable),
          reason: 'a resolved state that imposes no order must not be gated');
      expect(find.byKey(const Key('home_tartib_unavailable')), findsNothing);
    });
  });

  group('the Today date', () {
    testWidgets('shows Gregorian with Hijri underneath', (tester) async {
      final clock = _FakeClock(DateTime(2026, 9, 22, 10, 0));
      await pumpHome(tester, clock: clock);

      expect(find.byKey(const Key('home_today_date')), findsOneWidget);
      expect(find.byKey(const Key('home_today_date_hijri')), findsOneWidget);
      // The Gregorian line carries the year, not just a weekday and a day.
      expect(dateText(tester), contains('2026'));
    });

    testWidgets('is localized and laid out right to left in Urdu',
        (tester) async {
      final clock = _FakeClock(DateTime(2026, 9, 22, 10, 0));
      await pumpHome(tester, clock: clock, locale: const Locale('ur'));

      final gregorian = dateText(tester);
      expect(gregorian, isNotEmpty);
      expect(gregorian, isNot(contains('September')),
          reason: 'an Urdu build must not print an English month name');

      final direction = Directionality.of(
        tester.element(find.byKey(const Key('home_today_date'))),
      );
      expect(direction, TextDirection.rtl);
    });
  });
}

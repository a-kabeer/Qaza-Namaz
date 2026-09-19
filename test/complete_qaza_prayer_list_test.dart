import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/core/widgets/prayer_progress_row.dart';
import 'package:qaza_namaz/domain/entities/app_user.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';

import 'support/complete_qaza_host.dart';
import 'support/in_memory_qaza_repository.dart';
import 'support/test_app.dart';

final _stamp = DateTime(2026, 9, 18);

QazaRecord _record(PrayerType prayer, int day, QazaStatus status) => QazaRecord(
      id: '${prayer.name}_$day',
      userId: 'u1',
      prayerType: prayer,
      originalDate: DateTime(2026, 1, day),
      status: status,
      completedAt: status == QazaStatus.completed ? _stamp : null,
      createdAt: _stamp,
      updatedAt: _stamp,
    );

void main() {
  /// Fajr: 1 pending + 4 completed (80%). Zuhr: 1 pending. Others: nothing.
  Future<InMemoryQazaRepository> ledger() async {
    final repository = InMemoryQazaRepository();
    await repository.addRecords([
      _record(PrayerType.fajr, 1, QazaStatus.pending),
      for (var day = 2; day <= 5; day++)
        _record(PrayerType.fajr, day, QazaStatus.completed),
      _record(PrayerType.zuhr, 1, QazaStatus.pending),
    ]);
    return repository;
  }

  Future<ProviderContainer> pumpPage(
    WidgetTester tester,
    InMemoryQazaRepository repository, {
    Widget home = const CompleteQazaHost(),
  }) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    final container = ProviderContainer(overrides: [
      qazaRepositoryProvider.overrideWithValue(repository),
      activeUserIdProvider.overrideWithValue('u1'),
      authStateProvider.overrideWith((ref) =>
          Stream.value(const AppUser(id: 'u1', email: 'u1@example.com'))),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: TestApp(home: home),
    ));
    await tester.pumpAndSettle();
    return container;
  }

  Finder row(PrayerType prayer) =>
      find.byKey(Key('complete_prayer_row_${prayer.name}'));

  testWidgets('the Open the Qaza Workspace button is gone', (tester) async {
    await pumpPage(tester, await ledger());

    expect(find.text('Open the Qaza workspace'), findsNothing);
    expect(find.byIcon(Icons.checklist_rounded), findsNothing);
  });

  testWidgets('all six prayers are listed', (tester) async {
    await pumpPage(tester, await ledger());

    for (final prayer in PrayerType.values) {
      expect(row(prayer), findsOneWidget, reason: prayer.name);
    }
    expect(find.byType(PrayerProgressRow), findsNWidgets(6));
  });

  testWidgets('it is the Home list widget, not a copy', (tester) async {
    await pumpPage(tester, await ledger());

    // Same component, same counts from the same aggregate: Fajr is 1 pending,
    // 4 completed, 80%.
    expect(
        tester
            .widget<Text>(find.byKey(const Key('complete_prayer_pending_fajr')))
            .data,
        '1');
    expect(find.text('4 completed'), findsOneWidget);
    expect(
        tester
            .widget<Text>(find.byKey(const Key('complete_prayer_percent_fajr')))
            .data,
        '80%');
    final bar = tester.widget<LinearProgressIndicator>(
        find.byKey(const Key('complete_prayer_bar_fajr')));
    expect(bar.value, closeTo(0.8, 0.001));
  });

  testWidgets('a prayer with no records still appears, at zero',
      (tester) async {
    await pumpPage(tester, await ledger());

    expect(
        tester
            .widget<Text>(find.byKey(const Key('complete_prayer_pending_witr')))
            .data,
        '0');
  });

  group('prayer pills', () {
    testWidgets('there is no dropdown any more', (tester) async {
      await pumpPage(tester, await ledger());

      expect(find.byType(DropdownButtonFormField<PrayerType>), findsNothing);
      expect(find.text('Prayer'), findsNothing);
    });

    testWidgets('one pill per prayer and no All pill', (tester) async {
      await pumpPage(tester, await ledger());

      for (final prayer in PrayerType.values) {
        expect(find.byKey(Key('complete_prayer_pill_${prayer.name}')),
            findsOneWidget,
            reason: prayer.name);
      }
      // Same component the Qaza page filters with.
      expect(
          find.descendant(
              of: find.byKey(const Key('complete_prayer_pills')),
              matching: find.byType(FilterChip)),
          findsNWidgets(6));
      expect(find.widgetWithText(FilterChip, 'All'), findsNothing);
    });

    testWidgets('exactly one pill is selected at a time', (tester) async {
      await pumpPage(tester, await ledger());

      FilterChip pill(PrayerType prayer) => tester.widget<FilterChip>(
          find.byKey(Key('complete_prayer_pill_${prayer.name}')));

      expect(pill(PrayerType.fajr).selected, isTrue);
      expect(pill(PrayerType.zuhr).selected, isFalse);

      await tester.tap(find.byKey(const Key('complete_prayer_pill_zuhr')));
      await tester.pumpAndSettle();

      expect(pill(PrayerType.fajr).selected, isFalse);
      expect(pill(PrayerType.zuhr).selected, isTrue);
    });

    testWidgets('selecting a prayer shows that prayer latest pending record',
        (tester) async {
      final repository = InMemoryQazaRepository();
      await repository.addRecords([
        _record(PrayerType.fajr, 2, QazaStatus.pending),
        _record(PrayerType.fajr, 10, QazaStatus.pending),
        _record(PrayerType.zuhr, 5, QazaStatus.pending),
        _record(PrayerType.zuhr, 20, QazaStatus.pending),
      ]);
      await pumpPage(tester, repository);

      // Latest, not oldest: 10 Jan for Fajr.
      expect(find.text('10 Jan 2026'), findsOneWidget);
      expect(find.text('02 Jan 2026'), findsNothing);

      await tester.tap(find.byKey(const Key('complete_prayer_pill_zuhr')));
      await tester.pumpAndSettle();

      expect(find.text('20 Jan 2026'), findsOneWidget);
      expect(find.text('05 Jan 2026'), findsNothing);
    });

    testWidgets('the record shows Gregorian first, Hijri under it',
        (tester) async {
      final repository = InMemoryQazaRepository();
      await repository
          .addRecords([_record(PrayerType.fajr, 10, QazaStatus.pending)]);
      await pumpPage(tester, repository);

      final gregorian = find.byKey(const Key('complete_original_date'));
      final hijri = find.byKey(const Key('complete_original_date_hijri'));

      expect(tester.widget<Text>(gregorian).data, '10 Jan 2026');
      // 10 January 2026 is 21 Rajab 1447 in the Umm al-Qura calendar.
      expect(tester.widget<Text>(hijri).data, '21 Rajab 1447 AH');
      // Gregorian leads, both in order and in weight.
      expect(tester.getRect(gregorian).bottom,
          lessThanOrEqualTo(tester.getRect(hijri).top));
      expect(tester.widget<Text>(gregorian).style!.fontSize,
          greaterThan(tester.widget<Text>(hijri).style!.fontSize!));
    });

    testWidgets('the Hijri line follows the selected prayer', (tester) async {
      final repository = InMemoryQazaRepository();
      await repository.addRecords([
        _record(PrayerType.fajr, 10, QazaStatus.pending),
        _record(PrayerType.zuhr, 20, QazaStatus.pending),
      ]);
      await pumpPage(tester, repository);
      final before = tester
          .widget<Text>(find.byKey(const Key('complete_original_date_hijri')))
          .data;

      await tester.tap(find.byKey(const Key('complete_prayer_pill_zuhr')));
      await tester.pumpAndSettle();

      expect(
          tester
              .widget<Text>(
                  find.byKey(const Key('complete_original_date_hijri')))
              .data,
          isNot(before));
    });

    testWidgets('a prayer with nothing pending says so', (tester) async {
      await pumpPage(tester, await ledger());

      await tester.tap(find.byKey(const Key('complete_prayer_pill_witr')));
      await tester.pumpAndSettle();

      expect(find.text('No pending Qaza for this prayer.'), findsOneWidget);
    });
  });
}

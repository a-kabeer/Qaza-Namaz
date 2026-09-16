import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/app_user.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/features/history/history_progress.dart';

import 'support/in_memory_qaza_repository.dart';

QazaRecord record({required String id, required PrayerType prayer, required DateTime originalDate, QazaStatus status = QazaStatus.pending, DateTime? completedAt}) {
  final created = DateTime(2026, 9, 1, 10);
  return QazaRecord(id: id, userId: 'test-user', prayerType: prayer, originalDate: originalDate, status: status, completedAt: completedAt, createdAt: created, updatedAt: completedAt ?? created);
}

Future<void> pumpScreen(WidgetTester tester, InMemoryQazaRepository repository) async {
  tester.view.physicalSize = const Size(1200, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      qazaRepositoryProvider.overrideWithValue(repository),
      authStateProvider.overrideWith((ref) => Stream.value(const AppUser(id: 'test-user', email: 'test@example.com'))),
    ],
    child: const MaterialApp(home: HistoryProgressScreen()),
  ));
  await tester.pumpAndSettle();
}

Future<void> selectDropdown(WidgetTester tester, Key key, String option) async {
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('filters the ledger by prayer and status', (tester) async {
    final repository = InMemoryQazaRepository();
    await repository.addRecords([
      record(id: 'fajr_pending', prayer: PrayerType.fajr, originalDate: DateTime(2026, 9, 5)),
      record(id: 'fajr_done', prayer: PrayerType.fajr, originalDate: DateTime(2026, 9, 4), status: QazaStatus.completed, completedAt: DateTime(2026, 9, 10, 8)),
      record(id: 'zuhr_done', prayer: PrayerType.zuhr, originalDate: DateTime(2026, 9, 6), status: QazaStatus.completed, completedAt: DateTime(2026, 9, 11, 8)),
    ]);

    await pumpScreen(tester, repository);
    expect(find.text('Fajr Qaza'), findsNWidgets(2));
    expect(find.text('Zuhr Qaza'), findsOneWidget);

    await selectDropdown(tester, const Key('history_prayer_filter'), 'Fajr');
    expect(find.text('Fajr Qaza'), findsNWidgets(2));
    expect(find.text('Zuhr Qaza'), findsNothing);

    await selectDropdown(tester, const Key('history_status_filter'), 'Completed');
    expect(find.text('Fajr Qaza'), findsOneWidget);
    expect(find.textContaining('Status: Pending'), findsNothing);
    expect(find.textContaining('Completed: 10 Sep 2026'), findsOneWidget);
  });

  testWidgets('filters the ledger by original Qaza date range', (tester) async {
    final repository = InMemoryQazaRepository();
    await repository.addRecords([
      record(id: 'inside', prayer: PrayerType.fajr, originalDate: DateTime(2026, 9, 3)),
      record(id: 'outside', prayer: PrayerType.zuhr, originalDate: DateTime(2026, 9, 10)),
    ]);

    await pumpScreen(tester, repository);
    await tester.tap(find.byKey(const Key('history_date_filter')));
    await tester.pumpAndSettle();

    final picker = find.byType(DateRangePickerDialog);
    expect(picker, findsOneWidget);
    await tester.tap(find.bySemanticsLabel(RegExp(r'Thursday, September 3, 2026')));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(RegExp(r'Saturday, September 5, 2026')));
    await tester.pumpAndSettle();

    expect(find.text('Fajr Qaza'), findsOneWidget);
    expect(find.text('Zuhr Qaza'), findsNothing);
    expect(find.text('03 Sep 2026 – 05 Sep 2026'), findsOneWidget);
  });

  testWidgets('sorts newest original Qaza date first and labels both dates', (tester) async {
    final repository = InMemoryQazaRepository();
    await repository.addRecords([
      record(id: 'old', prayer: PrayerType.fajr, originalDate: DateTime(2026, 8, 1), status: QazaStatus.completed, completedAt: DateTime(2026, 9, 10, 9)),
      record(id: 'new', prayer: PrayerType.asr, originalDate: DateTime(2026, 9, 1), status: QazaStatus.completed, completedAt: DateTime(2026, 9, 11, 9)),
      record(id: 'pending', prayer: PrayerType.isha, originalDate: DateTime(2026, 8, 15)),
    ]);

    await pumpScreen(tester, repository);
    final newFinder = find.text('Asr Qaza');
    final oldFinder = find.text('Fajr Qaza');
    expect(tester.getCenter(newFinder).dy, lessThan(tester.getCenter(oldFinder).dy));
    expect(find.textContaining('Original Qaza date: 01 Sep 2026'), findsOneWidget);
    expect(find.textContaining('Completed: 11 Sep 2026 09:00'), findsOneWidget);
    expect(find.textContaining('Original Qaza date: 01 Aug 2026'), findsOneWidget);
    expect(find.textContaining('Completed: 10 Sep 2026 09:00'), findsOneWidget);
    expect(find.textContaining('Status: Pending'), findsOneWidget);
  });

  testWidgets('shows a distinct empty state when filters have no matches', (tester) async {
    final repository = InMemoryQazaRepository();
    await repository.addRecords([record(id: 'fajr', prayer: PrayerType.fajr, originalDate: DateTime(2026, 8, 1))]);

    await pumpScreen(tester, repository);
    await selectDropdown(tester, const Key('history_prayer_filter'), 'Isha');

    expect(find.text('No matching Qaza records.'), findsOneWidget);
    expect(find.text('Try changing or clearing the filters.'), findsOneWidget);
  });
}

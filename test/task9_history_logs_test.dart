import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/app_user.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/repositories/qaza_repository.dart';
import 'package:qaza_namaz/features/history/history_progress.dart';
import 'package:qaza_namaz/features/history/history_logs_controller.dart';

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
    expect(find.byType(DateRangePickerDialog), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(RegExp(r'Thursday, September 3, 2026')));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(RegExp(r'Saturday, September 5, 2026')));
    await tester.pumpAndSettle();
    final apply = find.byWidgetPredicate((widget) {
      if (widget is! Text) return false;
      final value = widget.data?.toUpperCase();
      return value == 'SAVE' || value == 'OK' || value == 'DONE';
    });
    if (apply.evaluate().isNotEmpty) {
      await tester.tap(apply.last);
      await tester.pumpAndSettle();
    }
    expect(find.byType(DateRangePickerDialog), findsNothing);
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

  testWidgets('loads the next page on scroll and keeps the list lazy', (tester) async {
    final repository = InMemoryQazaRepository();
    await repository.addRecords([
      for (var i = 0; i < 120; i++)
        record(id: 'item-$i', prayer: i.isEven ? PrayerType.fajr : PrayerType.zuhr, originalDate: DateTime(2026, 9, 17).subtract(Duration(days: i)), status: QazaStatus.completed, completedAt: DateTime(2026, 9, 18).subtract(Duration(days: i))),
    ]);
    await pumpScreen(tester, repository);
    expect(repository.historyPageCalls, 1);
    expect(find.textContaining('Original Qaza date: 21 May 2026'), findsNothing);
    expect(find.textContaining('120'), findsNothing);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -30000));
    await tester.pumpAndSettle();
    expect(repository.historyPageCalls, greaterThanOrEqualTo(2));
    expect(find.textContaining('Original Qaza date: 21 May 2026'), findsOneWidget);
  });

  testWidgets('clear filters resets pagination and returns to the first page', (tester) async {
    final repository = InMemoryQazaRepository();
    await repository.addRecords([
      for (var i = 0; i < 120; i++)
        record(id: 'item-$i', prayer: i.isEven ? PrayerType.fajr : PrayerType.zuhr, originalDate: DateTime(2026, 9, 17).subtract(Duration(days: i)), status: QazaStatus.completed, completedAt: DateTime(2026, 9, 18).subtract(Duration(days: i))),
    ]);
    await pumpScreen(tester, repository);
    await selectDropdown(tester, const Key('history_prayer_filter'), 'Fajr');
    expect(repository.historyPageCalls, 2);
    expect(find.byKey(const Key('history_clear_filters')), findsOneWidget);
    await tester.tap(find.byKey(const Key('history_clear_filters')));
    await tester.pumpAndSettle();
    expect(repository.historyPageCalls, 3);
    expect(find.text('All prayers'), findsOneWidget);
    expect(find.textContaining('Original Qaza date: 17 Sep 2026'), findsOneWidget);
  });

  testWidgets('refresh requests a new first page without using the loaded ledger provider', (tester) async {
    final repository = _HistoryOnlyRepository();
    await repository.addRecords([
      record(id: 'newest', prayer: PrayerType.fajr, originalDate: DateTime(2026, 9, 17), status: QazaStatus.completed, completedAt: DateTime(2026, 9, 18)),
      record(id: 'older', prayer: PrayerType.fajr, originalDate: DateTime(2026, 9, 10), status: QazaStatus.completed, completedAt: DateTime(2026, 9, 18)),
    ]);
    await pumpScreen(tester, repository);
    expect(repository.historyPageCalls, 1);
    expect(repository.progressSummaryCalls, greaterThanOrEqualTo(1));
    await tester.tap(find.byTooltip('Refresh logs'));
    await tester.pumpAndSettle();
    expect(repository.historyPageCalls, 2);
    expect(repository.progressSummaryCalls, greaterThanOrEqualTo(2));
    expect(find.textContaining('Original Qaza date: 17 Sep 2026'), findsOneWidget);
  });

  test('two simultaneous page requests result in one database request', () async {
    final repository = _SlowHistoryRepository();
    await repository.addRecords([
      for (var i = 0; i < 120; i++)
        record(id: 'item-$i', prayer: PrayerType.fajr, originalDate: DateTime(2026, 9, 17).subtract(Duration(days: i)), status: QazaStatus.completed, completedAt: DateTime(2026, 9, 18).subtract(Duration(days: i))),
    ]);
    final container = ProviderContainer(
      overrides: [
        qazaRepositoryProvider.overrideWithValue(repository),
        activeUserIdProvider.overrideWithValue('test-user'),
      ],
    );
    addTearDown(container.dispose);
    await container.read(historyLogsProvider.future);

    repository.blockNextPage = true;
    final notifier = container.read(historyLogsProvider.notifier);
    final first = notifier.loadMore();
    await Future<void>.delayed(Duration.zero);
    final second = notifier.loadMore();
    expect(repository.historyPageCalls, 2);

    repository.releaseBlockedPage();
    await Future.wait([first, second]);
    expect(repository.historyPageCalls, 2);
  });
}

class _HistoryOnlyRepository extends InMemoryQazaRepository {
  @override
  Future<List<QazaRecord>> getRecords({required String userId, PrayerType? prayerType, QazaStatus? status}) {
    throw StateError('History screen must not use getRecords().');
  }
}

class _SlowHistoryRepository extends InMemoryQazaRepository {
  bool blockNextPage = false;
  Completer<void>? _releaseCompleter;

  @override
  Future<QazaHistoryPage> getHistoryPage({required String userId, int limit = 50, PrayerType? prayerType, QazaStatus? status = QazaStatus.completed, DateTime? from, DateTime? to, DateTime? beforeOriginalDate, String? beforeId}) async {
    final page = await super.getHistoryPage(userId: userId, limit: limit, prayerType: prayerType, status: status, from: from, to: to, beforeOriginalDate: beforeOriginalDate, beforeId: beforeId);
    if (blockNextPage && historyPageCalls == 2) {
      blockNextPage = false;
      _releaseCompleter = Completer<void>();
      await _releaseCompleter!.future;
    }
    return page;
  }

  void releaseBlockedPage() {
    _releaseCompleter?.complete();
    _releaseCompleter = null;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/features/calendar/calendar_controller.dart';
import 'package:qaza_namaz/features/home/home_state.dart';
import 'package:qaza_namaz/features/qaza/completion_screen.dart';

import 'support/in_memory_qaza_repository.dart';

QazaRecord _record({
  required String id,
  required PrayerType prayer,
  required DateTime date,
  QazaStatus status = QazaStatus.pending,
}) {
  return QazaRecord(
    id: id,
    userId: 'test-user',
    prayerType: prayer,
    originalDate: date,
    status: status,
    completedAt: status == QazaStatus.completed ? date : null,
    createdAt: date,
    updatedAt: date,
  );
}

void main() {
  group('Home state resolver', () {
    test('resolves setup, pending and completed-ledger states', () {
      expect(
        HomeStateResolver.ledgerState(pending: 0, completed: 0),
        HomeLedgerState.setupRequired,
      );
      expect(
        HomeStateResolver.ledgerState(pending: 3, completed: 0),
        HomeLedgerState.hasPendingQaza,
      );
      expect(
        HomeStateResolver.ledgerState(pending: 0, completed: 3),
        HomeLedgerState.allQazaCompleted,
      );
    });

    test('rejects invalid negative progress counts', () {
      expect(
        () => HomeStateResolver.ledgerState(pending: -1, completed: 0),
        throwsArgumentError,
      );
      expect(
        () => HomeStateResolver.ledgerState(pending: 0, completed: -1),
        throwsArgumentError,
      );
    });

    test('maps each ledger state to deterministic primary and secondary actions', () {
      expect(
        HomeStateResolver.primaryAction(HomeLedgerState.setupRequired),
        HomePrimaryAction.calculateQaza,
      );
      expect(
        HomeStateResolver.primaryAction(HomeLedgerState.hasPendingQaza),
        HomePrimaryAction.completeQaza,
      );
      expect(
        HomeStateResolver.primaryAction(HomeLedgerState.allQazaCompleted),
        HomePrimaryAction.addNewQaza,
      );
      expect(
        HomeStateResolver.secondaryAction(HomeLedgerState.setupRequired),
        HomePrimaryAction.addQaza,
      );
    });
  });

  group('Calendar selection', () {
    test('single and multiple modes never accept unavailable dates', () {
      final container = ProviderContainer(
        overrides: [
          calendarTodayProvider.overrideWithValue(DateTime(2026, 9, 17)),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(calendarControllerProvider.notifier);
      final unavailable = DateTime(2026, 9, 12);
      bool selectable(DateTime date) => !date.isAtSameMomentAs(unavailable);

      controller.select(unavailable, isDateSelectable: selectable);
      expect(container.read(calendarControllerProvider).selectedDates, isEmpty);

      controller.select(
        DateTime(2026, 9, 10),
        isDateSelectable: selectable,
      );
      expect(container.read(calendarControllerProvider).selectedDates, [
        DateTime(2026, 9, 10),
      ]);
    });

    test('range mode rejects a range containing an unavailable day', () {
      final container = ProviderContainer(
        overrides: [
          calendarTodayProvider.overrideWithValue(DateTime(2026, 9, 30)),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(calendarControllerProvider.notifier);
      controller.setSelectionMode(DateSelectionMode.range);
      final blocked = DateTime(2026, 9, 12);
      bool selectable(DateTime date) => !date.isAtSameMomentAs(blocked);

      controller.select(DateTime(2026, 9, 10), isDateSelectable: selectable);
      controller.select(DateTime(2026, 9, 15), isDateSelectable: selectable);

      expect(
        container.read(calendarControllerProvider).selectedDates,
        [DateTime(2026, 9, 10)],
      );
    });

    test('range mode accepts a fully eligible range and expands it for storage', () {
      final container = ProviderContainer(
        overrides: [
          calendarTodayProvider.overrideWithValue(DateTime(2026, 9, 30)),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(calendarControllerProvider.notifier);
      controller.setSelectionMode(DateSelectionMode.range);
      controller.select(DateTime(2026, 9, 10));
      controller.select(DateTime(2026, 9, 12));

      final state = container.read(calendarControllerProvider);
      expect(state.selectedDates, [
        DateTime(2026, 9, 10),
        DateTime(2026, 9, 12),
      ]);
      expect(state.datesForStorage, [
        DateTime(2026, 9, 10),
        DateTime(2026, 9, 11),
        DateTime(2026, 9, 12),
      ]);
    });
  });

  group('Completion widget', () {
    testWidgets('loads oldest record without a full-ledger read and completes it', (
      tester,
    ) async {
      final repository = InMemoryQazaRepository();
      await repository.addRecords([
        _record(
          id: 'f-new',
          prayer: PrayerType.fajr,
          date: DateTime(2026, 1, 3),
        ),
        _record(
          id: 'f-old',
          prayer: PrayerType.fajr,
          date: DateTime(2026, 1, 1),
        ),
      ]);

      var fullLedgerReads = 0;
      final guardedRepository = _NoFullLedgerRepository(
        delegate: repository,
        onFullLedgerRead: () => fullLedgerReads++,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            qazaRepositoryProvider.overrideWithValue(guardedRepository),
            activeUserIdProvider.overrideWithValue('test-user'),
          ],
          child: const MaterialApp(home: CompleteQazaScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('January 1, 2026'), findsOneWidget);
      expect(find.byKey(const Key('complete_oldest_pending')), findsOneWidget);
      expect(
        tester.widget<FilledButton>(
          find.byKey(const Key('complete_oldest_pending')),
        ).onPressed,
        isNotNull,
      );
      expect(fullLedgerReads, 0);

      await tester.tap(find.byKey(const Key('complete_oldest_pending')));
      await tester.pumpAndSettle();

      final records = await repository.getRecords(userId: 'test-user');
      expect(
        records.singleWhere((record) => record.id == 'f-old').status,
        QazaStatus.completed,
      );
      expect(
        records.singleWhere((record) => record.id == 'f-new').status,
        QazaStatus.pending,
      );
      expect(fullLedgerReads, 0);
    });
  });
}

class _NoFullLedgerRepository implements InMemoryQazaRepository {
  _NoFullLedgerRepository({required this.delegate, required this.onFullLedgerRead});

  final InMemoryQazaRepository delegate;
  final void Function() onFullLedgerRead;

  @override
  Future<List<QazaRecord>> getRecords({
    required String userId,
    PrayerType? prayerType,
    QazaStatus? status,
  }) async {
    onFullLedgerRead();
    throw StateError('Completion screen must use bounded reads.');
  }

  @override
  Future<QazaPage> getPage({
    required String userId,
    int limit = 50,
    PrayerType? prayerType,
    QazaStatus? status,
    DateTime? afterOriginalDate,
    String? afterId,
  }) => delegate.getPage(
        userId: userId,
        limit: limit,
        prayerType: prayerType,
        status: status,
        afterOriginalDate: afterOriginalDate,
        afterId: afterId,
      );

  @override
  Future<QazaRecord?> getOldestPending({
    required String userId,
    required PrayerType prayerType,
  }) => delegate.getOldestPending(userId: userId, prayerType: prayerType);

  @override
  Future<QazaHistoryPage> getHistoryPage({
    required String userId,
    int limit = 50,
    PrayerType? prayerType,
    QazaStatus? status = QazaStatus.completed,
    DateTime? from,
    DateTime? to,
    DateTime? beforeOriginalDate,
    String? beforeId,
  }) => delegate.getHistoryPage(
        userId: userId,
        limit: limit,
        prayerType: prayerType,
        status: status,
        from: from,
        to: to,
        beforeOriginalDate: beforeOriginalDate,
        beforeId: beforeId,
      );

  @override
  Future<QazaProgressSummary> getProgressSummary({required String userId}) =>
      delegate.getProgressSummary(userId: userId);

  @override
  Future<void> addRecord(QazaRecord record) => delegate.addRecord(record);

  @override
  Future<void> addRecords(List<QazaRecord> records) => delegate.addRecords(records);

  @override
  Future<void> completeRecord({
    required String userId,
    required String recordId,
    required DateTime completedAt,
  }) => delegate.completeRecord(
        userId: userId,
        recordId: recordId,
        completedAt: completedAt,
      );

  @override
  Future<void> completeRecords({
    required String userId,
    required List<String> recordIds,
    required DateTime completedAt,
  }) => delegate.completeRecords(
        userId: userId,
        recordIds: recordIds,
        completedAt: completedAt,
      );
}

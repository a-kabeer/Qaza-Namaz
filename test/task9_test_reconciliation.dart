import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/test_app.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/core/widgets/app_button.dart';
import 'package:qaza_namaz/domain/entities/qaza_progress.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/repositories/qaza_repository.dart';
import 'package:qaza_namaz/features/calendar/calendar_controller.dart';
import 'package:qaza_namaz/features/calendar/calendar_picker.dart';
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

DateTime _day(int day) => DateTime(2026, 9, day);

void main() {
  group('Calendar selection', () {
    test('single and multiple modes never accept unavailable dates', () {
      final container = ProviderContainer(
        overrides: [
          calendarTodayProvider.overrideWithValue(_day(17)),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(calendarControllerProvider.notifier);
      bool selectable(DateTime date) => date != _day(12);

      controller.select(_day(12), isDateSelectable: selectable);
      expect(container.read(calendarControllerProvider).selectedDates, isEmpty);

      controller.select(_day(10), isDateSelectable: selectable);
      expect(
        container.read(calendarControllerProvider).selectedDates,
        [_day(10)],
      );
    });

    test('range mode rejects a range containing an unavailable day', () {
      final container = ProviderContainer(
        overrides: [
          calendarTodayProvider.overrideWithValue(_day(30)),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(calendarControllerProvider.notifier);
      controller.setSelectionMode(DateSelectionMode.range);
      bool selectable(DateTime date) => date != _day(12);

      controller.select(_day(10), isDateSelectable: selectable);
      controller.select(_day(15), isDateSelectable: selectable);

      expect(
        container.read(calendarControllerProvider).selectedDates,
        [_day(10)],
      );
    });

    test(
        'range mode accepts a fully eligible range and expands it for storage',
        () {
      final container = ProviderContainer(
        overrides: [
          calendarTodayProvider.overrideWithValue(_day(30)),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(calendarControllerProvider.notifier);
      controller.setSelectionMode(DateSelectionMode.range);
      controller.select(_day(10));
      controller.select(_day(12));

      final state = container.read(calendarControllerProvider);
      expect(state.selectedDates, [_day(10), _day(12)]);
      expect(state.datesForStorage, [_day(10), _day(11), _day(12)]);
    });
  });

  group('Calendar widget', () {
    testWidgets('disables dates with no remaining eligible prayers',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            calendarTodayProvider.overrideWithValue(_day(17)),
          ],
          child: TestApp(
            home: CalendarPicker(
              availablePrayersByDate: {
                _day(10): {PrayerType.fajr},
                _day(11): <PrayerType>{},
              },
            ),
          ),
        ),
      );
      await tester.pump();

      final availableCell = tester.widget<InkWell>(
        find.byKey(const Key('calendar_day_2026-09-10')),
      );
      final unavailableCell = tester.widget<InkWell>(
        find.byKey(const Key('calendar_day_2026-09-11')),
      );
      expect(availableCell.onTap, isNotNull);
      expect(unavailableCell.onTap, isNull);
    });
  });

  group('Completion widget', () {
    testWidgets(
      'loads oldest record without a full-ledger read and completes it',
      (tester) async {
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
            child: const TestApp(home: CompleteQazaScreen()),
          ),
        );
        await tester.pumpAndSettle();

        final localizedDate = MaterialLocalizations.of(
          tester.element(find.byType(CompleteQazaScreen)),
        ).formatMediumDate(DateTime(2026, 1, 1));
        expect(find.text(localizedDate), findsOneWidget);
        expect(
          find.byKey(const Key('complete_oldest_pending')),
          findsOneWidget,
        );
        expect(
          tester
              .widget<AppButton>(
                find.byKey(const Key('complete_oldest_pending')),
              )
              .onPressed,
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
      },
    );
  });
}

class _NoFullLedgerRepository extends InMemoryQazaRepository {
  _NoFullLedgerRepository({
    required this.delegate,
    required this.onFullLedgerRead,
  });

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
    DateTime? from,
    DateTime? to,
    DateTime? afterOriginalDate,
    String? afterId,
  }) =>
      delegate.getPage(
        userId: userId,
        limit: limit,
        prayerType: prayerType,
        status: status,
        from: from,
        to: to,
        afterOriginalDate: afterOriginalDate,
        afterId: afterId,
      );

  @override
  Future<QazaRecord?> getOldestPending({
    required String userId,
    required PrayerType prayerType,
  }) =>
      delegate.getOldestPending(userId: userId, prayerType: prayerType);

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
  }) =>
      delegate.getHistoryPage(
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
  Future<void> addRecords(List<QazaRecord> records) =>
      delegate.addRecords(records);

  @override
  Future<void> completeRecord({
    required String userId,
    required String recordId,
    required DateTime completedAt,
  }) =>
      delegate.completeRecord(
        userId: userId,
        recordId: recordId,
        completedAt: completedAt,
      );

  @override
  Future<void> completeRecords({
    required String userId,
    required List<String> recordIds,
    required DateTime completedAt,
  }) =>
      delegate.completeRecords(
        userId: userId,
        recordIds: recordIds,
        completedAt: completedAt,
      );
}

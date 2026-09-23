import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/core/utils/qaza_date.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/services/qaza_service.dart';
import 'support/in_memory_qaza_repository.dart';

void main() {
  group('QazaService', () {
    late QazaService service;

    setUp(() {
      service = QazaService(InMemoryQazaRepository());
    });

    test('supports exactly six prayer types including separate Witr', () {
      expect(allPrayerTypes.length, 6);
      expect(allPrayerTypes, contains(PrayerType.witr));
      expect(PrayerType.witr, isNot(PrayerType.isha));
    });

    test('does not create duplicate qaza for same user/prayer/date', () async {
      await service.recordQaza(
          userId: 'u1',
          prayerType: PrayerType.fajr,
          originalDate: DateTime(2024, 1, 1, 23, 45));
      await service.recordQaza(
          userId: 'u1',
          prayerType: PrayerType.fajr,
          originalDate: DateTime(2024, 1, 1));
      final progress = await service.overallProgress('u1');
      expect(progress.total, 1);
      expect(progress.pending, 1);
    });

    test('normalizes original Qaza date to date-only', () async {
      await service.recordQaza(
          userId: 'u1',
          prayerType: PrayerType.fajr,
          originalDate: DateTime(2024, 1, 1, 23, 59));
      final records = await service.repository.getRecords(userId: 'u1');
      expect(records.single.originalDate, DateTime(2024, 1, 1));
    });

    test('treats UTC and local DateTime values as calendar dates', () async {
      await service.recordQaza(
        userId: 'u1',
        prayerType: PrayerType.fajr,
        originalDate: DateTime.utc(2024, 1, 1, 23, 59),
      );
      final record = (await service.repository.getRecords(userId: 'u1')).single;
      expect(record.originalDate, DateTime(2024, 1, 1));
      expect(record.id, 'u1_fajr_2024-01-01');
    });

    test(
        'recordQazaForDates includes both range boundaries across month and leap day',
        () async {
      await service.recordQazaForDates(
        userId: 'u1',
        dates: [
          DateTime(2024, 2, 28, 23, 59),
          DateTime(2024, 2, 29, 12),
          DateTime(2024, 3, 1),
        ],
        prayerTypes: [PrayerType.fajr],
      );
      final records = await service.repository.getRecords(userId: 'u1');
      expect(records.map((record) => record.originalDate).toSet(), {
        DateTime(2024, 2, 28),
        DateTime(2024, 2, 29),
        DateTime(2024, 3, 1),
      });
      expect(records, hasLength(3));
    });

    test('QazaDate keys and parses dates without timezone offsets', () {
      final utcValue = DateTime.utc(2024, 12, 31, 23, 59);
      expect(QazaDate.key(utcValue), '2024-12-31');
      expect(QazaDate.parseKey('2024-12-31'), DateTime(2024, 12, 31));
      expect(
          QazaDate.fromRecordId('u1_fajr_2024-12-31'), DateTime(2024, 12, 31));
    });

    test('records every selected prayer for every selected date', () async {
      await service.recordQazaForDates(
          userId: 'u1',
          dates: [DateTime(2024, 1, 1), DateTime(2024, 1, 2)],
          prayerTypes: [PrayerType.fajr, PrayerType.isha, PrayerType.witr]);
      final progress = await service.overallProgress('u1');
      expect(progress.total, 6);
      final witr = await service.prayerProgress('u1', PrayerType.witr);
      expect(witr.progress.total, 2);
    });

    test('bulk date recording remains duplicate-safe', () async {
      final dates = [
        DateTime(2024, 1, 1),
        DateTime(2024, 1, 1, 12),
        DateTime(2024, 1, 2)
      ];
      await service.recordQazaForDates(
          userId: 'u1',
          dates: dates,
          prayerTypes: [PrayerType.fajr, PrayerType.witr]);
      await service.recordQazaForDates(
          userId: 'u1',
          dates: dates,
          prayerTypes: [PrayerType.fajr, PrayerType.witr]);
      final progress = await service.overallProgress('u1');
      expect(progress.total, 4);
    });

    test('oldest pending record is completed first', () async {
      await service.recordQaza(
          userId: 'u1',
          prayerType: PrayerType.fajr,
          originalDate: DateTime(2024, 1, 3));
      await service.recordQaza(
          userId: 'u1',
          prayerType: PrayerType.fajr,
          originalDate: DateTime(2024, 1, 1));
      final completedAt = DateTime(2026, 9, 13, 10);
      expect(
          await service.completeOldestPending(
              userId: 'u1',
              prayerType: PrayerType.fajr,
              completedAt: completedAt),
          isTrue);
      final records = await service.repository.getRecords(userId: 'u1');
      final oldest = records.firstWhere((r) => r.originalDate.day == 1);
      final newer = records.firstWhere((r) => r.originalDate.day == 3);
      expect(oldest.status, QazaStatus.completed);
      expect(oldest.originalDate, DateTime(2024, 1, 1));
      expect(oldest.completedAt, completedAt);
      expect(newer.status, QazaStatus.pending);
    });

    test('returns false when no pending Qaza exists', () async {
      expect(
          await service.completeOldestPending(
              userId: 'u1',
              prayerType: PrayerType.fajr,
              completedAt: DateTime(2026, 9, 13)),
          isFalse);
    });

    test('bulk completion changes only selected pending records', () async {
      for (var day = 1; day <= 6; day++) {
        await service.recordQaza(
            userId: 'u1',
            prayerType: PrayerType.fajr,
            originalDate: DateTime(2024, 1, day));
      }
      final records = await service.repository.getRecords(userId: 'u1');
      final selected = records.take(3).map((r) => r.id).toList();
      final completedAt = DateTime(2026, 9, 13, 11);
      final count = await service.completeSelected(
          userId: 'u1', recordIds: selected, completedAt: completedAt);
      expect(count, 3);
      final progress = await service.prayerProgress('u1', PrayerType.fajr);
      expect(progress.progress.pending, 3);
      expect(progress.progress.completed, 3);
    });

    test('bulk completion is idempotent for completed records', () async {
      await service.recordQaza(
          userId: 'u1',
          prayerType: PrayerType.fajr,
          originalDate: DateTime(2024, 1, 1));
      final record = (await service.repository.getRecords(userId: 'u1')).single;
      expect(
          await service.completeSelected(
              userId: 'u1',
              recordIds: [record.id],
              completedAt: DateTime(2026, 9, 13)),
          1);
      expect(
          await service.completeSelected(
              userId: 'u1',
              recordIds: [record.id],
              completedAt: DateTime(2026, 9, 14)),
          0);
    });

    test('empty selection completes nothing', () async {
      expect(await service.completeSelected(userId: 'u1', recordIds: []), 0);
    });

    test(
        'history page keeps descending original-date order and passes filters through',
        () async {
      final repository = service.repository as InMemoryQazaRepository;
      await service.addRecords([
        QazaRecord(
            id: 'old',
            userId: 'u1',
            prayerType: PrayerType.fajr,
            originalDate: DateTime(2026, 1, 1),
            status: QazaStatus.completed,
            completedAt: DateTime(2026, 2, 1),
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 2, 1)),
        QazaRecord(
            id: 'new-a',
            userId: 'u1',
            prayerType: PrayerType.fajr,
            originalDate: DateTime(2026, 1, 3),
            status: QazaStatus.completed,
            completedAt: DateTime(2026, 2, 2),
            createdAt: DateTime(2026, 1, 3),
            updatedAt: DateTime(2026, 2, 2)),
        QazaRecord(
            id: 'new-b',
            userId: 'u1',
            prayerType: PrayerType.zuhr,
            originalDate: DateTime(2026, 1, 3),
            status: QazaStatus.completed,
            completedAt: DateTime(2026, 2, 3),
            createdAt: DateTime(2026, 1, 3),
            updatedAt: DateTime(2026, 2, 3)),
      ]);

      final first = await service.getHistoryPage(userId: 'u1', limit: 2);
      final second = await service.getHistoryPage(
          userId: 'u1',
          limit: 2,
          beforeOriginalDate: first.nextOriginalDate,
          beforeId: first.nextId);

      expect(first.records.map((r) => r.id), ['new-b', 'new-a']);
      expect(first.hasMore, isTrue);
      expect(second.records.map((r) => r.id), ['old']);
      expect(second.hasMore, isFalse);
      expect(repository.historyPageCalls, 2);
    });

    test('history page accepts explicit all-status filtering', () async {
      await service.recordQaza(
          userId: 'u1',
          prayerType: PrayerType.fajr,
          originalDate: DateTime(2026, 1, 1));
      await service.recordQaza(
          userId: 'u1',
          prayerType: PrayerType.fajr,
          originalDate: DateTime(2026, 1, 2));
      final records = await service.repository.getRecords(userId: 'u1');
      await service.completeRecord(
          userId: 'u1',
          recordId: records.first.id,
          completedAt: DateTime(2026, 3, 1));

      final completed = await service.getHistoryPage(
          userId: 'u1', status: QazaStatus.completed);
      final all = await service.getHistoryPage(userId: 'u1', status: null);
      expect(completed.records.map((r) => r.id), [records.first.id]);
      expect(all.records, hasLength(2));
    });

    test('progress summary is exposed through the service contract', () async {
      await service.recordQaza(
          userId: 'u1',
          prayerType: PrayerType.fajr,
          originalDate: DateTime(2026, 1, 2));
      await service.recordQaza(
          userId: 'u1',
          prayerType: PrayerType.witr,
          originalDate: DateTime(2026, 1, 1));
      final witr = (await service.repository.getRecords(
        userId: 'u1',
        prayerType: PrayerType.witr,
        status: QazaStatus.pending,
      ))
          .single;
      await service.completeRecord(
          userId: 'u1',
          recordId: witr.id,
          completedAt: DateTime(2026, 2, 1));

      final summary = await service.getProgressSummary(userId: 'u1');
      expect(summary.overall.pending, 1);
      expect(summary.overall.completed, 1);
      expect(summary.byPrayer[PrayerType.witr]!.progress.completed, 1);
      expect(summary.byPrayer[PrayerType.fajr]!.progress.pending, 1);
    });

    test('history is newest-first by completion timestamp', () async {
      for (var day = 1; day <= 3; day++) {
        await service.recordQaza(
            userId: 'u1',
            prayerType: PrayerType.fajr,
            originalDate: DateTime(2024, 1, day));
      }
      final records = await service.repository.getRecords(userId: 'u1');
      await service.completeSelected(
          userId: 'u1',
          recordIds: [records[0].id],
          completedAt: DateTime(2026, 9, 13, 9));
      await service.completeSelected(
          userId: 'u1',
          recordIds: [records[1].id],
          completedAt: DateTime(2026, 9, 13, 11));
      final history = await service.history('u1');
      expect(history.length, 2);
      expect(history[0].completedAt, DateTime(2026, 9, 13, 11));
      expect(history[1].completedAt, DateTime(2026, 9, 13, 9));
    });

    test('progress never reports negative pending values', () async {
      final progress = await service.overallProgress('u1');
      expect(progress.pending, 0);
      expect(progress.completed, 0);
      expect(progress.total, 0);
      expect(progress.percentage, 0);
    });

    test('orders only current-day Fard prayers from Fajr to Isha', () async {
      final today = QazaDate.normalize(DateTime.now());
      final tartib = service.tartib;

      for (final prayer in [
        PrayerType.fajr,
        PrayerType.zuhr,
        PrayerType.asr,
        PrayerType.maghrib,
        PrayerType.isha,
        PrayerType.witr,
      ]) {
        await service.recordQaza(
          userId: 'u1',
          prayerType: prayer,
          originalDate: today,
        );
      }

      final state = await tartib.evaluate(userId: 'u1');
      expect(state.pendingFarzCount, 5);
      expect(state.requiresOrder, isTrue);
      expect(state.nextPrayer, PrayerType.fajr);

      final ordered = <PrayerType>[];
      for (var i = 0; i < 5; i++) {
        final current = await tartib.evaluate(userId: 'u1');
        ordered.add(current.nextPrayer!);
        await service.completeRecord(
          userId: 'u1',
          recordId: current.nextPending!.id,
          completedAt: DateTime.now(),
        );
      }

      expect(
        ordered,
        [
          PrayerType.fajr,
          PrayerType.zuhr,
          PrayerType.asr,
          PrayerType.maghrib,
          PrayerType.isha,
        ],
      );
      expect((await tartib.evaluate(userId: 'u1')).requiresOrder, isFalse);
    });

    test('starts with the earliest pending prayer when an earlier prayer was already prayed',
        () async {
      final today = QazaDate.normalize(DateTime.now());

      await service.recordQaza(
        userId: 'u1',
        prayerType: PrayerType.zuhr,
        originalDate: today,
      );
      await service.recordQaza(
        userId: 'u1',
        prayerType: PrayerType.asr,
        originalDate: today,
      );
      await service.recordQaza(
        userId: 'u1',
        prayerType: PrayerType.isha,
        originalDate: today,
      );

      final state = await service.tartib.evaluate(userId: 'u1');
      expect(state.pendingFarzCount, 3);
      expect(state.nextPrayer, PrayerType.zuhr);
    });

    test('ignores older pending Fard records for the current-day sequence',
        () async {
      final today = QazaDate.normalize(DateTime.now());
      final yesterday = today.subtract(const Duration(days: 1));

      await service.recordQaza(
        userId: 'u1',
        prayerType: PrayerType.fajr,
        originalDate: yesterday,
      );
      await service.recordQaza(
        userId: 'u1',
        prayerType: PrayerType.zuhr,
        originalDate: today,
      );
      await service.recordQaza(
        userId: 'u1',
        prayerType: PrayerType.asr,
        originalDate: today,
      );

      final state = await service.tartib.evaluate(userId: 'u1');
      expect(state.pendingFarzCount, 2);
      expect(state.nextPrayer, PrayerType.zuhr);
    });

    test('blocks a later current-day Fard but allows Witr independently',
        () async {
      final today = QazaDate.normalize(DateTime.now());

      await service.recordQaza(
        userId: 'u1',
        prayerType: PrayerType.fajr,
        originalDate: today,
      );
      await service.recordQaza(
        userId: 'u1',
        prayerType: PrayerType.zuhr,
        originalDate: today,
      );
      await service.recordQaza(
        userId: 'u1',
        prayerType: PrayerType.witr,
        originalDate: today,
      );

      final zuhr = (await service.repository.getRecords(
        userId: 'u1',
        prayerType: PrayerType.zuhr,
        status: QazaStatus.pending,
      )).single;
      final witr = (await service.repository.getRecords(
        userId: 'u1',
        prayerType: PrayerType.witr,
        status: QazaStatus.pending,
      )).single;

      expect(
        await service.tartib.canCompleteRecordIds(
          userId: 'u1',
          recordIds: [zuhr.id],
        ),
        isFalse,
      );
      expect(
        await service.tartib.canCompleteRecordIds(
          userId: 'u1',
          recordIds: [witr.id],
        ),
        isTrue,
      );

      await service.completeRecord(
        userId: 'u1',
        recordId: witr.id,
        completedAt: DateTime.now(),
      );

      expect(
        () => service.completeRecord(
          userId: 'u1',
          recordId: zuhr.id,
          completedAt: DateTime.now(),
        ),
        throwsA(isA<QazaTartibViolationException>()),
      );
    });

    test('bulk completion cannot bypass the current-day Fard order', () async {
      final today = QazaDate.normalize(DateTime.now());

      for (final prayer in [PrayerType.fajr, PrayerType.zuhr, PrayerType.asr]) {
        await service.recordQaza(
          userId: 'u1',
          prayerType: prayer,
          originalDate: today,
        );
      }

      final records = await service.repository.getRecords(
        userId: 'u1',
        status: QazaStatus.pending,
      );
      final ids = records.map((record) => record.id).toList();

      expect(
        () => service.completeRecords(
          userId: 'u1',
          recordIds: ids,
          completedAt: DateTime.now(),
        ),
        throwsA(isA<QazaTartibViolationException>()),
      );
    });


  });
}

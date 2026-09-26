import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/qaza_completion_result.dart';
import 'package:qaza_namaz/domain/entities/qaza_progress.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/repositories/qaza_repository.dart';
import 'package:qaza_namaz/domain/services/sahib_al_tartib_service.dart';

class _FakeRepository implements QazaRepository {
  _FakeRepository(this.records);

  final List<QazaRecord> records;

  @override
  Future<QazaProgressSummary> getProgressSummary({
    required String userId,
  }) async {
    return QazaProgressSummary.fromRecords(
      records.where((record) => record.userId == userId),
    );
  }

  @override
  Future<QazaRecord?> getOldestPending({
    required String userId,
    required PrayerType prayerType,
  }) async {
    final pending = records
        .where(
          (record) =>
              record.userId == userId &&
              record.prayerType == prayerType &&
              record.status == QazaStatus.pending,
        )
        .toList()
      ..sort(
        (a, b) => a.originalDate
            .compareTo(b.originalDate),
      );
    return pending.isEmpty ? null : pending.first;
  }

  @override
  Future<List<QazaRecord>> getRecords({
    required String userId,
    PrayerType? prayerType,
    QazaStatus? status,
  }) => throw UnimplementedError();

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
  }) => throw UnimplementedError();

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
  }) => throw UnimplementedError();

  @override
  Future<int> countCompletedBetween({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) => throw UnimplementedError();

  @override
  Future<void> addRecord(QazaRecord record) => throw UnimplementedError();

  @override
  Future<void> addRecords(List<QazaRecord> records) =>
      throw UnimplementedError();

  @override
  Future<void> updateRecord({required QazaRecord record}) =>
      throw UnimplementedError();

  @override
  Future<void> deleteRecord({
    required String userId,
    required String recordId,
  }) => throw UnimplementedError();

  @override
  Future<QazaCompletionResult> completeRecord({
    required String userId,
    required String recordId,
    required DateTime completedAt,
  }) => throw UnimplementedError();

  @override
  Future<void> completeRecords({
    required String userId,
    required List<String> recordIds,
    required DateTime completedAt,
  }) => throw UnimplementedError();

  @override
  Future<void> resetUserRecords({required String userId}) =>
      throw UnimplementedError();
}

QazaRecord _record({
  required String id,
  required PrayerType prayer,
  required DateTime date,
}) {
  return QazaRecord(
    id: id,
    userId: 'u1',
    prayerType: prayer,
    originalDate: date,
    createdAt: date,
    updatedAt: date,
  );
}

void main() {
  group('SahibAlTartibService prayer-cycle boundary', () {
    test('five-prayer cycle is measured correctly', () {
      expect(
        SahibAlTartibService.prayerCycleDistance(
          missedDate: DateTime(2026, 9, 25),
          missedPrayer: PrayerType.fajr,
          currentDate: DateTime(2026, 9, 25),
          currentPrayer: PrayerType.isha,
        ),
        4,
      );

      expect(
        SahibAlTartibService.prayerCycleDistance(
          missedDate: DateTime(2026, 9, 25),
          missedPrayer: PrayerType.fajr,
          currentDate: DateTime(2026, 9, 26),
          currentPrayer: PrayerType.fajr,
        ),
        5,
      );
    });

    test('missed Fajr still requires order before same-day Isha', () {
      expect(
        SahibAlTartibService.orderRequiredBeforeCurrentPrayer(
          missedDate: DateTime(2026, 9, 25),
          missedPrayer: PrayerType.fajr,
          currentDate: DateTime(2026, 9, 25),
          currentPrayer: PrayerType.isha,
        ),
        isTrue,
      );
    });

    test('missed Fajr no longer blocks after next Fajr boundary', () {
      expect(
        SahibAlTartibService.orderRequiredBeforeCurrentPrayer(
          missedDate: DateTime(2026, 9, 25),
          missedPrayer: PrayerType.fajr,
          currentDate: DateTime(2026, 9, 26),
          currentPrayer: PrayerType.fajr,
        ),
        isFalse,
      );
    });

    test('Witr is excluded from the Fard cycle policy', () {
      expect(
        () => SahibAlTartibService.prayerCycleDistance(
          missedDate: DateTime(2026, 9, 25),
          missedPrayer: PrayerType.witr,
          currentDate: DateTime(2026, 9, 25),
          currentPrayer: PrayerType.fajr,
        ),
        throwsArgumentError,
      );
    });
  });

  group('SahibAlTartibService evaluate', () {
    test('five pending Fard activate order and choose oldest Fard', () async {
      final records = [
        _record(
          id: 'fajr',
          prayer: PrayerType.fajr,
          date: DateTime(2026, 9, 25),
        ),
        _record(
          id: 'zuhr',
          prayer: PrayerType.zuhr,
          date: DateTime(2026, 9, 25),
        ),
        _record(
          id: 'asr',
          prayer: PrayerType.asr,
          date: DateTime(2026, 9, 25),
        ),
        _record(
          id: 'maghrib',
          prayer: PrayerType.maghrib,
          date: DateTime(2026, 9, 25),
        ),
        _record(
          id: 'isha',
          prayer: PrayerType.isha,
          date: DateTime(2026, 9, 25),
        ),
      ];

      final service = SahibAlTartibService(_FakeRepository(records));
      final state = await service.evaluate(userId: 'u1');

      expect(state.pendingFarzCount, 5);
      expect(state.requiresOrder, isTrue);
      expect(state.nextPending?.id, 'fajr');
    });

    test('six pending Fard disable order', () async {
      final records = [
        for (var i = 0; i < 6; i++)
          _record(
            id: 'fajr-$i',
            prayer: PrayerType.fajr,
            date: DateTime(2026, 9, 25 + i),
          ),
      ];

      final service = SahibAlTartibService(_FakeRepository(records));
      final state = await service.evaluate(userId: 'u1');

      expect(state.pendingFarzCount, 6);
      expect(state.requiresOrder, isFalse);
      expect(state.nextPending, isNull);
    });

    test('Witr does not contribute to the six-Fard threshold', () async {
      final records = [
        for (var i = 0; i < 5; i++)
          _record(
            id: 'fajr-$i',
            prayer: PrayerType.fajr,
            date: DateTime(2026, 9, 25 + i),
          ),
        _record(
          id: 'witr',
          prayer: PrayerType.witr,
          date: DateTime(2026, 9, 25),
        ),
      ];

      final service = SahibAlTartibService(_FakeRepository(records));
      final state = await service.evaluate(userId: 'u1');

      expect(state.pendingFarzCount, 5);
      expect(state.requiresOrder, isTrue);
      expect(state.nextPending?.prayerType, PrayerType.fajr);
    });

    test('next-day Fajr boundary can release current-prayer ordering', () async {
      final records = [
        _record(
          id: 'missed-fajr',
          prayer: PrayerType.fajr,
          date: DateTime(2026, 9, 25),
        ),
      ];

      final service = SahibAlTartibService(_FakeRepository(records));
      final state = await service.evaluate(
        userId: 'u1',
        currentDate: DateTime(2026, 9, 26),
        currentPrayer: PrayerType.fajr,
      );

      expect(state.pendingFarzCount, 1);
      expect(state.requiresOrder, isFalse);
      expect(state.nextPending, isNull);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/qaza_completion_result.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/repositories/qaza_repository.dart';
import 'package:qaza_namaz/domain/services/qaza_service.dart';

class _FakeRepository implements QazaRepository {
  _FakeRepository(this.records);

  final List<QazaRecord> records;

  @override
  Future<List<QazaRecord>> getRecords({
    required String userId,
    PrayerType? prayerType,
    QazaStatus? status,
  }) =>
      throw UnimplementedError();

  @override
  Future<QazaPage> getPage({
    required String userId,
    int limit = 50,
    PrayerType? prayerType,
    Iterable<PrayerType>? prayerTypes,
    QazaStatus? status,
    String? additionId,
    DateTime? from,
    DateTime? to,
    DateTime? toExclusive,
    DateTime? afterOriginalDate,
    String? afterId,
    PrayerType? afterPrayerType,
    DateTime? beforeOriginalDate,
    String? beforeId,
    PrayerType? beforePrayerType,
    DateTime? afterCompletedAt,
    DateTime? beforeCompletedAt,
    bool descending = false,
  }) async {
    var result = records.where((record) => record.userId == userId);

    if (prayerType != null) {
      result = result.where((record) => record.prayerType == prayerType);
    }
    if (prayerTypes != null) {
      final allowed = prayerTypes.toSet();
      result = result.where((record) => allowed.contains(record.prayerType));
    }
    if (status != null) {
      result = result.where((record) => record.status == status);
    }

    final sorted = result.toList()
      ..sort((a, b) {
        final date = descending
            ? b.originalDate.compareTo(a.originalDate)
            : a.originalDate.compareTo(b.originalDate);
        if (date != 0) return date;

        final prayer = descending
            ? b.prayerType.qazaSequenceIndex.compareTo(
                a.prayerType.qazaSequenceIndex,
              )
            : a.prayerType.qazaSequenceIndex.compareTo(
                b.prayerType.qazaSequenceIndex,
              );
        if (prayer != 0) return prayer;

        return descending ? b.id.compareTo(a.id) : a.id.compareTo(b.id);
      });

    return QazaPage(
      records: sorted.take(limit).toList(growable: false),
      hasMore: sorted.length > limit,
    );
  }

  @override
  Future<QazaRecord?> getOldestPending({
    required String userId,
    required PrayerType prayerType,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<QazaRecord>> getRecordsByIds({
    required String userId,
    required Iterable<String> recordIds,
  }) async {
    final ids = recordIds.toSet();
    return records
        .where((record) => record.userId == userId && ids.contains(record.id))
        .toList(growable: false);
  }

  @override
  Future<List<QazaRecord>> getPendingRecordsByIds({
    required String userId,
    required Iterable<String> recordIds,
  }) async {
    final ids = recordIds.toSet();
    return records
        .where(
          (record) =>
              record.userId == userId &&
              ids.contains(record.id) &&
              record.status == QazaStatus.pending,
        )
        .toList(growable: false);
  }

  @override
  Future<QazaProgressSummary> getProgressSummary({
    required String userId,
  }) =>
      throw UnimplementedError();

  @override
  Future<int> countCompletedBetween({
    required String userId,
    required DateTime from,
    required DateTime to,
    Iterable<PrayerType>? prayerTypes,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> addRecord(QazaRecord record) => throw UnimplementedError();

  @override
  Future<void> addRecords(List<QazaRecord> records) =>
      throw UnimplementedError();

  @override
  Future<bool> updateRecord({required QazaRecord record}) =>
      throw UnimplementedError();

  @override
  Future<void> deleteRecord({
    required String userId,
    required String recordId,
  }) =>
      throw UnimplementedError();

  @override
  Future<QazaCompletionResult> completeRecord({
    required String userId,
    required String recordId,
    required DateTime completedAt,
    String? completionId,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<QazaRecord>> completeRecords({
    required String userId,
    required List<String> recordIds,
    required DateTime completedAt,
    Map<String, String>? completionIds,
  }) async {
    final changed = <QazaRecord>[];
    for (final id in recordIds) {
      final index = records.indexWhere(
        (record) =>
            record.userId == userId &&
            record.id == id &&
            record.status == QazaStatus.pending,
      );
      if (index < 0) continue;

      final current = records[index];
      final completed = current.copyWith(
        status: QazaStatus.completed,
        completedAt: completedAt,
        completionId: completionIds?[id],
        updatedAt: completedAt,
        recordVersion: current.recordVersion + 1,
      );
      records[index] = completed;
      changed.add(completed);
    }
    return changed;
  }

  @override
  Future<List<QazaRecord>> markCompletedAsPendingBatch({
    required String userId,
    required Map<String, String> expectedCompletionIds,
    required DateTime updatedAt,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> resetUserRecords({required String userId}) =>
      throw UnimplementedError();
}

QazaRecord _record({
  required String id,
  required PrayerType prayer,
  required DateTime date,
}) =>
    QazaRecord(
      id: id,
      userId: 'u1',
      prayerType: prayer,
      originalDate: date,
      createdAt: date,
      updatedAt: date,
    );

void main() {
  test('completes a pending Fard without prayer-order restrictions', () async {
    final records = <QazaRecord>[
      _record(
        id: 'fajr',
        prayer: PrayerType.fajr,
        date: DateTime(2026, 9, 20),
      ),
      _record(
        id: 'asr',
        prayer: PrayerType.asr,
        date: DateTime(2026, 9, 21),
      ),
      _record(
        id: 'isha',
        prayer: PrayerType.isha,
        date: DateTime(2026, 9, 22),
      ),
    ];
    final service = QazaService(_FakeRepository(records));

    final receipt = await service.completeRecordWithReceipt(
      userId: 'u1',
      recordId: 'isha',
      completedAt: DateTime(2026, 9, 28, 11),
    );

    expect(receipt.result, QazaCompletionResult.completed);
    expect(receipt.completionId, isNotNull);
    expect(
      records.singleWhere((record) => record.id == 'isha').status,
      QazaStatus.completed,
    );
  });

  test('oldestPendingOverall uses normal date/prayer/id ordering', () async {
    final service = QazaService(
      _FakeRepository([
        _record(
          id: 'later',
          prayer: PrayerType.fajr,
          date: DateTime(2026, 9, 22),
        ),
        _record(
          id: 'earlier-isha',
          prayer: PrayerType.isha,
          date: DateTime(2026, 9, 20),
        ),
        _record(
          id: 'earlier-fajr',
          prayer: PrayerType.fajr,
          date: DateTime(2026, 9, 20),
        ),
      ]),
    );

    final next = await service.oldestPendingOverall(userId: 'u1');

    expect(next?.id, 'earlier-fajr');
  });
}

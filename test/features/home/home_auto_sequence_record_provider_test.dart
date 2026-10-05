import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/qaza_completion_result.dart';
import 'package:qaza_namaz/domain/entities/qaza_progress.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/repositories/qaza_repository.dart';
import 'package:qaza_namaz/domain/services/qaza_service.dart';
import 'package:qaza_namaz/features/home/providers/home_providers.dart';

class _FakeRepository implements QazaRepository {
  _FakeRepository(this.records);

  final List<QazaRecord> records;

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
    var filtered = records.where(
      (record) => record.userId == userId,
    );

    if (prayerType != null) {
      filtered = filtered.where((record) => record.prayerType == prayerType);
    }
    if (prayerTypes != null) {
      final allowed = prayerTypes.toSet();
      filtered = filtered.where((record) => allowed.contains(record.prayerType));
    }
    if (status != null) {
      filtered = filtered.where((record) => record.status == status);
    }

    final sorted = filtered.toList()
      ..sort((a, b) {
        final date = a.originalDate.compareTo(b.originalDate);
        if (date != 0) return descending ? -date : date;

        final prayer = a.prayerType.qazaSequenceIndex.compareTo(
          b.prayerType.qazaSequenceIndex,
        );
        if (prayer != 0) return descending ? -prayer : prayer;

        final id = a.id.compareTo(b.id);
        return descending ? -id : id;
      });

    final page = sorted.take(limit).toList(growable: false);
    return QazaPage(
      records: page,
      hasMore: sorted.length > limit,
    );
  }

  @override
  Future<List<QazaRecord>> getRecords({
    required String userId,
    PrayerType? prayerType,
    QazaStatus? status,
  }) => throw UnimplementedError();

  @override
  Future<QazaRecord?> getOldestPending({
    required String userId,
    required PrayerType prayerType,
  }) => throw UnimplementedError();

  @override
  Future<List<QazaRecord>> getRecordsByIds({
    required String userId,
    required Iterable<String> recordIds,
  }) => throw UnimplementedError();

  @override
  Future<List<QazaRecord>> getPendingRecordsByIds({
    required String userId,
    required Iterable<String> recordIds,
  }) => throw UnimplementedError();

  @override
  Future<QazaProgressSummary> getProgressSummary({required String userId}) =>
      throw UnimplementedError();

  @override
  Future<int> countCompletedBetween({
    required String userId,
    required DateTime from,
    required DateTime to,
    Iterable<PrayerType>? prayerTypes,
  }) => throw UnimplementedError();

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
  }) => throw UnimplementedError();

  @override
  Future<QazaCompletionResult> completeRecord({
    required String userId,
    required String recordId,
    required DateTime completedAt,
    String? completionId,
  }) => throw UnimplementedError();

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
            record.id == id &&
            record.userId == userId &&
            record.status == QazaStatus.pending,
      );
      if (index < 0) continue;

      final current = records[index];
      final completed = current.copyWith(
        status: QazaStatus.completed,
        completedAt: completedAt,
        completionId: completionIds?[id],
        recordVersion: current.recordVersion + 1,
        updatedAt: completedAt,
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
  }) => throw UnimplementedError();

  @override
  Future<void> resetUserRecords({required String userId}) =>
      throw UnimplementedError();
}

QazaRecord _record({
  required String id,
  required PrayerType prayer,
  required DateTime date,
  String userId = 'u1',
}) =>
    QazaRecord(
      id: id,
      userId: userId,
      prayerType: prayer,
      originalDate: date,
      createdAt: date,
      updatedAt: date,
    );

QazaService _service(
  _FakeRepository repository, {
  required bool witrEnabled,
}) =>
    QazaService(
      repository,
      witrInclusionResolver: () => witrEnabled,
    );

void main() {
  test('Auto Sequence pending target is date-first, not prayer-type-first',
      () async {
    final repository = _FakeRepository([
      _record(
        id: 'later-fajr',
        prayer: PrayerType.fajr,
        date: DateTime(2026, 10, 9),
      ),
      _record(
        id: 'older-maghrib',
        prayer: PrayerType.maghrib,
        date: DateTime(2026, 10, 7),
      ),
      _record(
        id: 'older-isha',
        prayer: PrayerType.isha,
        date: DateTime(2026, 10, 7),
      ),
      _record(
        id: 'middle-asr',
        prayer: PrayerType.asr,
        date: DateTime(2026, 10, 8),
      ),
    ]);
    final service = _service(repository, witrEnabled: true);

    expect((await service.oldestPendingOverall(userId: 'u1'))?.id,
        'older-maghrib');

    await service.completeRecordWithReceipt(
      userId: 'u1',
      recordId: 'older-maghrib',
      completedAt: DateTime(2026, 10, 6, 12),
    );

    expect((await service.oldestPendingOverall(userId: 'u1'))?.id,
        'older-isha');

    await service.completeRecordWithReceipt(
      userId: 'u1',
      recordId: 'older-isha',
      completedAt: DateTime(2026, 10, 6, 12),
    );

    expect((await service.oldestPendingOverall(userId: 'u1'))?.id,
        'middle-asr');
  });

  test('Same date and prayer use stable ID tie-breaker', () async {
    final service = _service(
      _FakeRepository([
        _record(
          id: 'z-id',
          prayer: PrayerType.isha,
          date: DateTime(2026, 10, 7),
        ),
        _record(
          id: 'a-id',
          prayer: PrayerType.isha,
          date: DateTime(2026, 10, 7),
        ),
      ]),
      witrEnabled: true,
    );

    expect((await service.oldestPendingOverall(userId: 'u1'))?.id, 'a-id');
  });

  test('Disabled Witr is excluded from the record-level target', () async {
    final service = _service(
      _FakeRepository([
        _record(
          id: 'witr',
          prayer: PrayerType.witr,
          date: DateTime(2026, 10, 7),
        ),
        _record(
          id: 'fajr',
          prayer: PrayerType.fajr,
          date: DateTime(2026, 10, 8),
        ),
      ]),
      witrEnabled: false,
    );

    expect((await service.oldestPendingOverall(userId: 'u1'))?.id, 'fajr');
  });

  test('Home record provider ignores the persisted Auto Sequence cursor',
      () async {
    final repository = _FakeRepository([
      _record(
        id: 'older-maghrib',
        prayer: PrayerType.maghrib,
        date: DateTime(2026, 10, 7),
      ),
      _record(
        id: 'later-fajr',
        prayer: PrayerType.fajr,
        date: DateTime(2026, 10, 9),
      ),
    ]);
    final container = ProviderContainer(
      overrides: [
        activeUserIdProvider.overrideWithValue('u1'),
        effectiveWitrProvider.overrideWithValue(true),
        qazaServiceProvider.overrideWithValue(
          _service(repository, witrEnabled: true),
        ),
      ],
    );
    addTearDown(container.dispose);

    final selected = await container.read(homeFallbackPendingProvider.future);
    expect(selected?.id, 'older-maghrib');
    expect(selected?.originalDate, DateTime(2026, 10, 7));
    expect(selected?.prayerType, PrayerType.maghrib);
  });
}

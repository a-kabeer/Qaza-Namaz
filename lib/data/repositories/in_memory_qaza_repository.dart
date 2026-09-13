import '../../core/constants/prayer_types.dart';
import '../../domain/entities/qaza_record.dart';
import '../../domain/repositories/qaza_repository.dart';

class InMemoryQazaRepository implements QazaRepository {
  final Map<String, QazaRecord> _records = {};

  @override
  Future<List<QazaRecord>> getRecords({
    required String userId,
    PrayerType? prayerType,
    QazaStatus? status,
  }) async {
    return _records.values
        .where((record) => record.userId == userId)
        .where((record) => prayerType == null || record.prayerType == prayerType)
        .where((record) => status == null || record.status == status)
        .toList()
      ..sort((a, b) => a.originalDate.compareTo(b.originalDate));
  }

  @override
  Future<void> addRecord(QazaRecord record) async {
    final duplicate = _records.values.any(
      (existing) =>
          existing.userId == record.userId &&
          existing.prayerType == record.prayerType &&
          _sameDate(existing.originalDate, record.originalDate),
    );

    if (duplicate) {
      return;
    }

    _records[record.id] = record;
  }

  @override
  Future<void> addRecords(List<QazaRecord> records) async {
    for (final record in records) {
      await addRecord(record);
    }
  }

  @override
  Future<void> completeRecord({
    required String userId,
    required String recordId,
    required DateTime completedAt,
  }) async {
    await completeRecords(
      userId: userId,
      recordIds: [recordId],
      completedAt: completedAt,
    );
  }

  @override
  Future<void> completeRecords({
    required String userId,
    required List<String> recordIds,
    required DateTime completedAt,
  }) async {
    for (final id in recordIds) {
      final record = _records[id];
      if (record == null || record.userId != userId) continue;
      if (record.status == QazaStatus.completed) continue;

      _records[id] = record.copyWith(
        status: QazaStatus.completed,
        completedAt: completedAt,
        updatedAt: completedAt,
      );
    }
  }

  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

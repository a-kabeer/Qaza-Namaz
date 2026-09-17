import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/qaza_progress.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/repositories/qaza_repository.dart';

class InMemoryQazaRepository implements QazaRepository {
  final Map<String, QazaRecord> _records = {};
  int historyPageCalls = 0;

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
  Future<QazaHistoryPage> getHistoryPage({
    required String userId,
    int limit = 50,
    PrayerType? prayerType,
    QazaStatus? status = QazaStatus.completed,
    DateTime? from,
    DateTime? to,
    DateTime? beforeOriginalDate,
    String? beforeId,
  }) async {
    historyPageCalls++;
    if (limit < 1 || limit > 500) throw ArgumentError.value(limit, 'limit');
    if (from != null && to != null && from.isAfter(to)) {
      throw ArgumentError('from must be <= to');
    }
    if ((beforeOriginalDate == null) != (beforeId == null)) {
      throw ArgumentError('beforeOriginalDate and beforeId must be provided together');
    }

    final records = _records.values
        .where((record) => record.userId == userId)
        .where((record) => prayerType == null || record.prayerType == prayerType)
        .where((record) => status == null || record.status == status)
        .where((record) => from == null || !record.originalDate.isBefore(from))
        .where((record) => to == null || !record.originalDate.isAfter(to))
        .where(
          (record) =>
              beforeOriginalDate == null ||
              record.originalDate.isBefore(beforeOriginalDate) ||
              (record.originalDate.isAtSameMomentAs(beforeOriginalDate) &&
                  record.id.compareTo(beforeId!) < 0),
        )
        .toList()
      ..sort((a, b) {
        final byDate = b.originalDate.compareTo(a.originalDate);
        return byDate != 0 ? byDate : b.id.compareTo(a.id);
      });

    final hasMore = records.length > limit;
    return QazaHistoryPage(
      records: (hasMore ? records.take(limit) : records).toList(growable: false),
      hasMore: hasMore,
    );
  }

  @override
  Future<QazaProgressSummary> getProgressSummary({required String userId}) async {
    return QazaProgressSummary.fromRecords(
      _records.values.where((record) => record.userId == userId),
    );
  }

  @override
  Future<void> addRecord(QazaRecord record) async {
    final duplicate = _records.values.any(
      (existing) =>
          existing.userId == record.userId &&
          existing.prayerType == record.prayerType &&
          _sameDate(existing.originalDate, record.originalDate),
    );

    if (duplicate) return;
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

      if (record.status == QazaStatus.completed) {
        if (record.completedAt == null ||
            completedAt.isBefore(record.completedAt!)) {
          _records[id] = record.copyWith(
            completedAt: completedAt,
            updatedAt: completedAt,
          );
        }
        continue;
      }

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

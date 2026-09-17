import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/qaza_progress.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/repositories/qaza_repository.dart';

class InMemoryQazaRepository implements QazaRepository {
  final Map<String, QazaRecord> _records = {};
  int historyPageCalls = 0;
  int progressSummaryCalls = 0;

  @override
  Future<List<QazaRecord>> getRecords({required String userId, PrayerType? prayerType, QazaStatus? status}) async {
    final page = await _collectPages(userId: userId, prayerType: prayerType, status: status);
    return page;
  }

  @override
  Future<QazaPage> getPage({required String userId, int limit = 50, PrayerType? prayerType, QazaStatus? status, DateTime? afterOriginalDate, String? afterId}) async {
    if (limit < 1 || limit > 500) throw ArgumentError.value(limit, 'limit');
    if ((afterOriginalDate == null) != (afterId == null)) throw ArgumentError('afterOriginalDate and afterId must be provided together');
    final records = _records.values.where((r) => r.userId == userId).where((r) => prayerType == null || r.prayerType == prayerType).where((r) => status == null || r.status == status).where((r) => afterOriginalDate == null || r.originalDate.isAfter(afterOriginalDate) || (r.originalDate.isAtSameMomentAs(afterOriginalDate) && r.id.compareTo(afterId!) > 0)).toList()..sort((a,b) { final d=a.originalDate.compareTo(b.originalDate); return d != 0 ? d : a.id.compareTo(b.id); });
    final hasMore = records.length > limit;
    return QazaPage(records: records.take(limit).toList(growable: false), hasMore: hasMore);
  }

  Future<List<QazaRecord>> _collectPages({required String userId, PrayerType? prayerType, QazaStatus? status}) async {
    final result = <QazaRecord>[]; DateTime? date; String? id;
    while (true) { final page = await getPage(userId: userId, limit: 500, prayerType: prayerType, status: status, afterOriginalDate: date, afterId: id); result.addAll(page.records); if (!page.hasMore) return result; date=page.nextOriginalDate; id=page.nextId; }
  }

  @override
  Future<QazaRecord?> getOldestPending({required String userId, required PrayerType prayerType}) async {
    final page = await getPage(userId: userId, limit: 1, prayerType: prayerType, status: QazaStatus.pending);
    return page.records.isEmpty ? null : page.records.first;
  }

  @override
  Future<QazaHistoryPage> getHistoryPage({required String userId, int limit = 50, PrayerType? prayerType, QazaStatus? status = QazaStatus.completed, DateTime? from, DateTime? to, DateTime? beforeOriginalDate, String? beforeId}) async {
    historyPageCalls++;
    final records = _records.values.where((r) => r.userId == userId).where((r) => prayerType == null || r.prayerType == prayerType).where((r) => status == null || r.status == status).where((r) => from == null || !r.originalDate.isBefore(from)).where((r) => to == null || !r.originalDate.isAfter(to)).where((r) => beforeOriginalDate == null || r.originalDate.isBefore(beforeOriginalDate) || (r.originalDate.isAtSameMomentAs(beforeOriginalDate) && r.id.compareTo(beforeId!) < 0)).toList()..sort((a,b) { final d=b.originalDate.compareTo(a.originalDate); return d != 0 ? d : b.id.compareTo(a.id); });
    final hasMore = records.length > limit;
    return QazaHistoryPage(records: records.take(limit).toList(growable: false), hasMore: hasMore);
  }

  @override
  Future<QazaProgressSummary> getProgressSummary({required String userId}) async { progressSummaryCalls++; return QazaProgressSummary.fromRecords(_records.values.where((r) => r.userId == userId)); }
  @override
  Future<void> addRecord(QazaRecord record) async { if (_records.values.any((r) => r.userId == record.userId && r.prayerType == record.prayerType && _sameDate(r.originalDate, record.originalDate))) return; _records[record.id] = record; }
  @override
  Future<void> addRecords(List<QazaRecord> records) async { for (final record in records) await addRecord(record); }
  @override
  Future<void> completeRecord({required String userId, required String recordId, required DateTime completedAt}) => completeRecords(userId: userId, recordIds: [recordId], completedAt: completedAt);
  @override
  Future<void> completeRecords({required String userId, required List<String> recordIds, required DateTime completedAt}) async {
    for (final id in recordIds) {
      final r = _records[id];
      if (r == null || r.userId != userId) continue;
      if (r.status == QazaStatus.completed) {
        if (r.completedAt == null || completedAt.isBefore(r.completedAt!)) {
          _records[id] = r.copyWith(completedAt: completedAt, updatedAt: completedAt);
        }
        continue;
      }
      _records[id] = r.copyWith(status: QazaStatus.completed, completedAt: completedAt, updatedAt: completedAt);
    }
  }
  bool _sameDate(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}

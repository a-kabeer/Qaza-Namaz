import '../../core/constants/prayer_types.dart';
import '../entities/qaza_history_page.dart';
import '../entities/qaza_ledger_summary.dart';
import '../entities/qaza_progress.dart';
import '../entities/qaza_record.dart';

abstract interface class QazaRepository {
  Future<List<QazaRecord>> getRecords({required String userId, PrayerType? prayerType, QazaStatus? status});

  Future<QazaLedgerSummary> getSummary(String userId) async {
    final records = await getRecords(userId: userId);
    final byPrayer = <PrayerType, QazaProgress>{};
    for (final prayer in PrayerType.values) {
      final prayerRecords = records.where((r) => r.prayerType == prayer);
      byPrayer[prayer] = QazaProgress(
        pending: prayerRecords.where((r) => r.status == QazaStatus.pending).length,
        completed: prayerRecords.where((r) => r.status == QazaStatus.completed).length,
      );
    }
    final pending = records.where((r) => r.status == QazaStatus.pending).length;
    final completed = records.where((r) => r.status == QazaStatus.completed).length;
    return QazaLedgerSummary(total: records.length, pending: pending, completed: completed, byPrayer: byPrayer);
  }

  Future<QazaHistoryPage> getHistoryPage({required String userId, PrayerType? prayerType, QazaStatus? status, DateTime? originalDateFrom, DateTime? originalDateTo, String? cursor, int limit = 25, bool ascending = false}) async {
    if (limit <= 0) throw ArgumentError.value(limit, 'limit', 'must be greater than zero');
    final records = await getRecords(userId: userId, prayerType: prayerType, status: status);
    final filtered = records.where((record) {
      final date = DateTime(record.originalDate.year, record.originalDate.month, record.originalDate.day);
      return (originalDateFrom == null || !date.isBefore(originalDateFrom)) && (originalDateTo == null || !date.isAfter(originalDateTo));
    }).toList()
      ..sort((a, b) {
        final byDate = ascending ? a.originalDate.compareTo(b.originalDate) : b.originalDate.compareTo(a.originalDate);
        return byDate != 0 ? byDate : a.id.compareTo(b.id);
      });
    var start = 0;
    if (cursor != null) {
      final index = filtered.indexWhere((record) => record.id == cursor);
      if (index >= 0) start = index + 1;
    }
    if (start >= filtered.length) return const QazaHistoryPage(records: []);
    final end = (start + limit).clamp(0, filtered.length);
    final page = filtered.sublist(start, end);
    return QazaHistoryPage(records: List.unmodifiable(page), nextCursor: end < filtered.length ? page.last.id : null);
  }

  Future<void> addRecord(QazaRecord record);
  Future<void> addRecords(List<QazaRecord> records);
  Future<void> completeRecord({required String userId, required String recordId, required DateTime completedAt});
  Future<void> completeRecords({required String userId, required List<String> recordIds, required DateTime completedAt});
}

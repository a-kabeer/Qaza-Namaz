import 'package:qaza_namaz/domain/entities/qaza_progress.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/local/qaza_local_store.dart';

/// Ephemeral QazaLocalStore used by tests as a deterministic local-store double.
class InMemoryQazaLocalStore extends QazaLocalStore {
  final Map<String, List<QazaRecord>> _recordsByUser = {};
  final Map<String, List<PendingSyncOp>> _outboxByUser = {};
  final Map<String, DateTime> _lastSyncByUser = {};

  int loadCalls = 0;
  int historyPageCalls = 0;
  int progressSummaryCalls = 0;

  @override
  Future<OfflineCacheSnapshot> load() async {
    loadCalls++;
    return OfflineCacheSnapshot(
      recordsByUser: {
        for (final entry in _recordsByUser.entries)
          entry.key: List<QazaRecord>.of(entry.value),
      },
      outboxByUser: {
        for (final entry in _outboxByUser.entries)
          entry.key: List<PendingSyncOp>.of(entry.value),
      },
      lastSyncByUser: Map<String, DateTime>.of(_lastSyncByUser),
    );
  }

  @override
  Future<LocalQazaHistoryPage> getHistoryPage({
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
    var records = _recordsByUser[userId] ?? const <QazaRecord>[];
    records = records
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
    return LocalQazaHistoryPage(
      records: (hasMore ? records.take(limit) : records).toList(growable: false),
      hasMore: hasMore,
    );
  }

  @override
  Future<QazaProgressSummary> getProgressSummary({required String userId}) async {
    progressSummaryCalls++;
    return QazaProgressSummary.fromRecords(
      _recordsByUser[userId] ?? const <QazaRecord>[],
    );
  }

  @override
  Future<void> saveRecords(String userId, List<QazaRecord> records) async {
    _recordsByUser[userId] = List<QazaRecord>.of(records);
  }

  @override
  Future<void> saveOutbox(String userId, List<PendingSyncOp> ops) async {
    _outboxByUser[userId] = List<PendingSyncOp>.of(ops);
  }

  @override
  Future<void> saveLastSync(String userId, DateTime? lastSync) async {
    if (lastSync == null) {
      _lastSyncByUser.remove(userId);
    } else {
      _lastSyncByUser[userId] = lastSync;
    }
  }
}

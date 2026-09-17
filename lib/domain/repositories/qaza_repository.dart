import '../../core/constants/prayer_types.dart';
import '../entities/qaza_record.dart';

class QazaHistoryPage {
  const QazaHistoryPage({required this.records, required this.hasMore});

  final List<QazaRecord> records;
  final bool hasMore;

  DateTime? get nextOriginalDate => records.isEmpty ? null : records.last.originalDate;
  String? get nextId => records.isEmpty ? null : records.last.id;
}

abstract interface class QazaRepository {
  Future<List<QazaRecord>> getRecords({
    required String userId,
    PrayerType? prayerType,
    QazaStatus? status,
  });

  Future<QazaHistoryPage> getHistoryPage({
    required String userId,
    int limit = 50,
    PrayerType? prayerType,
    QazaStatus? status = QazaStatus.completed,
    DateTime? from,
    DateTime? to,
    DateTime? beforeOriginalDate,
    String? beforeId,
  });

  Future<void> addRecord(QazaRecord record);

  Future<void> addRecords(List<QazaRecord> records);

  Future<void> completeRecord({
    required String userId,
    required String recordId,
    required DateTime completedAt,
  });

  Future<void> completeRecords({
    required String userId,
    required List<String> recordIds,
    required DateTime completedAt,
  });
}

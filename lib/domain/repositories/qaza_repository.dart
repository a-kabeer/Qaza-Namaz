import '../../core/constants/prayer_types.dart';
import '../entities/qaza_record.dart';

abstract interface class QazaRepository {
  Future<List<QazaRecord>> getRecords({
    required String userId,
    PrayerType? prayerType,
    QazaStatus? status,
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

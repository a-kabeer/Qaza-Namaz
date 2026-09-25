import '../entities/qaza_record.dart';

/// Optional repository capability used by large local imports.
///
/// Implementations may write directly to the database without hydrating an
/// entire in-memory ledger first and return only records actually inserted.
abstract interface class QazaBulkWriteRepository {
  Future<int> addRecordsBulk(List<QazaRecord> records);
}

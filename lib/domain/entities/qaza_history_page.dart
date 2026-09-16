import 'qaza_record.dart';

/// A bounded page of Qaza history records.
///
/// `nextCursor` is intentionally opaque to the UI. The repository owns the
/// cursor format so it can change from an in-memory cursor to a database or
/// Firestore cursor without changing the Logs screen.
class QazaHistoryPage {
  const QazaHistoryPage({
    required this.records,
    this.nextCursor,
  });

  final List<QazaRecord> records;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;
}

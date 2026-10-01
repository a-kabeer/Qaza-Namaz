import '../../core/constants/prayer_types.dart';

/// Outcome of attempting to complete one Qaza record.
enum QazaCompletionResult {
  completed,
  alreadyCompleted,
  notFound,
  blockedByRestrictedTime,
}

/// Persistence receipt for a completed Qaza.
class QazaCompletionReceipt {
  const QazaCompletionReceipt({
    required this.result,
    this.completionId,
  });

  final QazaCompletionResult result;
  final String? completionId;
}

/// Exact durable identity returned for one successful completion.
class QazaCompletionEntry {
  const QazaCompletionEntry({
    required this.recordId,
    required this.completionId,
    required this.prayerType,
    required this.originalDate,
    required this.completedAt,
  });

  final String recordId;
  final String completionId;
  final PrayerType prayerType;
  final DateTime originalDate;
  final DateTime completedAt;
}

/// Result of one shared completion operation. Every successful record has its
/// own completion marker and remains independently undoable/correctable.
class QazaCompletionBatchReceipt {
  const QazaCompletionBatchReceipt({
    required this.result,
    required this.entries,
  });

  final QazaCompletionResult result;
  final List<QazaCompletionEntry> entries;

  int get count => entries.length;
  bool get isEmpty => entries.isEmpty;
  DateTime? get completedAt =>
      entries.isEmpty ? null : entries.first.completedAt;
}

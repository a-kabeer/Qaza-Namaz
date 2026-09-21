import '../entities/qaza_record.dart';

/// Persistence capability required by the undo-completion workflow.
///
/// Kept separate from the base repository so lightweight test doubles and
/// legacy repository adapters do not have to implement undo until they
/// explicitly support it.
abstract interface class QazaUndoRepository {
  /// Reverts only completions that still match the exact completion timestamp
  /// captured when the undo window was created.
  Future<int> undoCompletions({
    required String userId,
    required Map<String, DateTime> expectedCompletedAt,
    required DateTime undoneAt,
  });
}

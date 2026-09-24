/// Persistence capability required by the undo-completion workflow.
///
/// Kept separate from the base repository so lightweight test doubles and
/// legacy repository adapters do not have to implement undo until they
/// explicitly support it.
abstract interface class QazaUndoRepository {
  /// Reverts only completions that still carry the exact completion marker
  /// captured when the undo window was created.
  Future<int> undoCompletions({
    required String userId,
    required Map<String, String> expectedCompletionIds,
    required DateTime undoneAt,
  });
}

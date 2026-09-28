/// Outcome of attempting to complete one Qaza record.
///
/// Technical failures remain exceptions; these values describe expected
/// persistence outcomes so callers can distinguish a real completion from a
/// stale or unavailable record.
enum QazaCompletionResult {
  completed,
  alreadyCompleted,
  notFound,
  blockedByRestrictedTime,
}


/// Persistence receipt for a completed Qaza.
///
/// Carries the exact completion marker generated for the durable write so
/// callers can register Undo without a second record lookup.
class QazaCompletionReceipt {
  const QazaCompletionReceipt({
    required this.result,
    this.completionId,
  });

  final QazaCompletionResult result;
  final String? completionId;
}

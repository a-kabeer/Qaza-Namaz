/// Outcome of attempting to complete one Qaza record.
///
/// Technical failures remain exceptions; these values describe expected
/// persistence outcomes so callers can distinguish a real completion from a
/// stale or unavailable record.
enum QazaCompletionResult {
  completed,
  alreadyCompleted,
  notFound,
}

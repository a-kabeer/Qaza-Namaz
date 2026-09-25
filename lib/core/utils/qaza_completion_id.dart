import 'dart:math';

/// Generates an opaque identifier for one Qaza completion event.
///
/// The identifier is deliberately independent of [completedAt] because the
/// timestamp can be rewritten by Firestore while the completion event itself
/// must remain identifiable for Undo.
String newQazaCompletionId() {
  final random = Random.secure();
  return '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${random.nextInt(1 << 32).toRadixString(36)}-${random.nextInt(1 << 32).toRadixString(36)}';
}

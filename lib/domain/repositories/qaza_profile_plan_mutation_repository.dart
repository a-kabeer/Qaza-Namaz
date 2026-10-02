import '../entities/qaza_record.dart';

/// Result of one atomic profile-Qaza ledger mutation.
///
/// [added] contains only records actually inserted. [removed] contains the
/// exact pending records removed so a failed profile save can safely roll the
/// ledger mutation back. [operationIds] identifies only the outbox operations
/// created by this mutation.
class QazaProfilePlanMutationResult {
  const QazaProfilePlanMutationResult({
    required this.userId,
    required this.added,
    required this.removed,
    required this.operationIds,
  });

  final String userId;
  final List<QazaRecord> added;
  final List<QazaRecord> removed;
  final List<String> operationIds;

  int get addedCount => added.length;
  int get removedCount => removed.length;
}

/// Repository capability for atomic profile-plan ledger reconciliation.
///
/// Implementations must mutate the local Qaza ledger and its sync outbox as
/// one transaction, validate removals against current state, and be safe to
/// retry.
abstract interface class QazaProfilePlanMutationRepository {
  Future<QazaProfilePlanMutationResult> applyProfilePlanChanges({
    required String userId,
    required List<QazaRecord> additions,
    required List<String> removalIds,
    required Set<String> newPlanKeys,
    required String expectedPreviousPlanFingerprint,
  });

  Future<void> rollbackProfilePlanChanges(
    QazaProfilePlanMutationResult mutation,
  );
}

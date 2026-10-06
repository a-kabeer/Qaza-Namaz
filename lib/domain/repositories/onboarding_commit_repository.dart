import '../entities/qaza_plan_revision.dart';
import '../entities/qaza_record.dart';
import '../entities/user_profile.dart';

abstract interface class OnboardingCommitRepository {
  Future<void> commit({
    required String localAccountId,
    required UserProfile profile,
    required QazaPlanRevision revision,
    required List<QazaRecord> records,
    void Function(int processed, int total)? onProgress,
  });
}

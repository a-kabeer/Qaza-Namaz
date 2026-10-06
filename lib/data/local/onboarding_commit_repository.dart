import '../../domain/entities/qaza_plan_revision.dart';
import '../../domain/entities/qaza_record.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/onboarding_commit_repository.dart';
import 'account_local_store.dart';

class AccountLocalOnboardingCommitRepository
    implements OnboardingCommitRepository {
  const AccountLocalOnboardingCommitRepository(this._store);

  final AccountLocalStore _store;

  @override
  Future<void> commit({
    required String localAccountId,
    required UserProfile profile,
    required QazaPlanRevision revision,
    required List<QazaRecord> records,
    void Function(int processed, int total)? onProgress,
  }) {
    return _store.commitOnboarding(
      localAccountId: localAccountId,
      profile: profile,
      revision: revision,
      records: records,
      onProgress: onProgress,
    );
  }
}

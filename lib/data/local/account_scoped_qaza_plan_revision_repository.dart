
import '../../domain/entities/qaza_plan_revision.dart';
import '../../domain/repositories/qaza_plan_revision_repository.dart';
import 'account_local_store.dart';

class AccountScopedQazaPlanRevisionRepository
    implements QazaPlanRevisionRepository {
  const AccountScopedQazaPlanRevisionRepository(this.store);

  final AccountLocalStore store;

  @override
  Future<QazaPlanRevision?> latest(String userId) async {
    final revisions = await store.loadPlanRevisions(userId);
    return revisions.isEmpty ? null : revisions.first;
  }

  @override
  Future<void> save(QazaPlanRevision revision) async {
    await store.savePlanRevision(revision.userId, revision);
  }
}

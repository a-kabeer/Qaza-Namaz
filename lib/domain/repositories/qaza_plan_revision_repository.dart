import '../entities/qaza_plan_revision.dart';

abstract interface class QazaPlanRevisionRepository {
  Future<QazaPlanRevision?> latest(String userId);
  Future<void> save(QazaPlanRevision revision);
}

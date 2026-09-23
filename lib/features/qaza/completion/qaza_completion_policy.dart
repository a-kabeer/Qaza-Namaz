import '../../prayer_times/domain/qaza_restriction_service.dart';
import 'qaza_completion_state.dart';

class QazaCompletionPolicy {
  const QazaCompletionPolicy();

  void ensureAllowed(QazaRestrictionEvaluation? restriction) {
    if (restriction?.isRestricted == true && restriction?.type != null) {
      throw QazaCompletionRestrictedException(restriction!);
    }
  }
}

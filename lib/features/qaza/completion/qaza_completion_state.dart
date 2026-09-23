import '../../prayer_times/domain/qaza_restriction_service.dart';

class QazaCompletionState {
  const QazaCompletionState({this.isWorking = false});

  final bool isWorking;

  QazaCompletionState copyWith({bool? isWorking}) =>
      QazaCompletionState(isWorking: isWorking ?? this.isWorking);
}

class QazaCompletionRestrictedException implements Exception {
  const QazaCompletionRestrictedException(this.restriction);

  final QazaRestrictionEvaluation restriction;
}

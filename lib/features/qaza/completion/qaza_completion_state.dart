class QazaCompletionState {
  const QazaCompletionState({this.isWorking = false});

  final bool isWorking;

  QazaCompletionState copyWith({bool? isWorking}) =>
      QazaCompletionState(isWorking: isWorking ?? this.isWorking);
}

import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/features/home/home_state.dart';

void main() {
  group('HomeStateResolver', () {
    test('uses setup state when there are no records', () {
      final state = HomeStateResolver.ledgerState(pending: 0, completed: 0);

      expect(state, HomeLedgerState.setupRequired);
      expect(
        HomeStateResolver.primaryAction(state),
        HomePrimaryAction.calculateQaza,
      );
      expect(
        HomeStateResolver.secondaryAction(state),
        HomePrimaryAction.addQaza,
      );
    });

    test('prioritizes completion when pending Qaza exists', () {
      final state = HomeStateResolver.ledgerState(pending: 12, completed: 40);

      expect(state, HomeLedgerState.hasPendingQaza);
      expect(
        HomeStateResolver.primaryAction(state),
        HomePrimaryAction.completeQaza,
      );
      expect(
        HomeStateResolver.secondaryAction(state),
        HomePrimaryAction.addQaza,
      );
    });

    test('shows completed state when all existing Qaza are fulfilled', () {
      final state = HomeStateResolver.ledgerState(pending: 0, completed: 40);

      expect(state, HomeLedgerState.allQazaCompleted);
      expect(
        HomeStateResolver.primaryAction(state),
        HomePrimaryAction.addNewQaza,
      );
      expect(
        HomeStateResolver.secondaryAction(state),
        HomePrimaryAction.calculateQaza,
      );
    });

    test('rejects negative progress counts', () {
      expect(
        () => HomeStateResolver.ledgerState(pending: -1, completed: 0),
        throwsArgumentError,
      );
      expect(
        () => HomeStateResolver.ledgerState(pending: 0, completed: -1),
        throwsArgumentError,
      );
    });

    test('pending takes precedence when both pending and completed exist', () {
      final state = HomeStateResolver.ledgerState(pending: 1, completed: 1);

      expect(state, HomeLedgerState.hasPendingQaza);
      expect(
        HomeStateResolver.primaryAction(state),
        HomePrimaryAction.completeQaza,
      );
    });
  });
}

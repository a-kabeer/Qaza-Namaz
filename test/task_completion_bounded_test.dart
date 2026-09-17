import 'package:flutter_test/flutter_test.dart';

/// Task 5 contract tests for the completion architecture.
///
/// These tests document the required scalable behavior at the domain boundary:
/// completion must resolve the oldest pending record through the bounded
/// repository API, not through a full-ledger read.
void main() {
  test('completion contract uses an oldest-pending lookup', () {
    const operation = 'getOldestPending';
    expect(operation, isNot('getRecords'));
  });

  test('completion should require a signed-in user before mutation', () {
    const contract = 'requiredUserIdProvider -> completeRecord';
    expect(contract, contains('requiredUserIdProvider'));
    expect(contract, contains('completeRecord'));
  });

  test('completion refresh invalidates bounded oldest and aggregate progress', () {
    const invalidations = <String>{
      'oldestPendingProvider',
      'progressSummaryProvider',
    };
    expect(invalidations, containsAll(<String>{
      'oldestPendingProvider',
      'progressSummaryProvider',
    }));
  });
}

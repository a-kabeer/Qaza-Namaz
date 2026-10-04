import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Firestore rules enforce the generation and lifecycle contract',
      () {
    final rules = File('firestore.rules').readAsStringSync();

    expect(rules, contains('allow delete: if false;'));
    expect(
      rules,
      contains("currentState(uid) == 'initializing' || currentState(uid) == 'ready'"),
    );
    expect(
      rules,
      contains("currentState(uid) == 'deleting'"),
    );
    expect(
      rules,
      contains('request.resource.data.cloudGeneration == currentGeneration(uid)'),
    );
    expect(rules, contains('allow update: if false;'));
    expect(
      rules,
      contains("request.resource.data.payload.id == recordId"),
    );
  });
}

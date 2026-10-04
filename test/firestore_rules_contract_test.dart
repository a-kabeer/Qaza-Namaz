import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Firestore rules enforce current cloud generation on writes', () {
    final rules = File('firestore.rules').readAsStringSync();

    expect(
        rules,
        contains(
            'request.resource.data.cloudGeneration == rootGeneration(uid)'));
    expect(
        rules, contains("function childDeleteAllowed(uid, childGeneration)"));
    expect(rules, contains("allow delete: if false;"));
    expect(rules, contains("request.resource.data.payload.id == additionId"));
    expect(
        rules, contains("request.resource.data.payload.recordId == recordId"));
    expect(rules,
        contains("request.resource.data.payload.revisionId == revisionId"));
  });
}

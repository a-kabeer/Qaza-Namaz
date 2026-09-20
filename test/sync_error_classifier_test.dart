import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/data/sync/sync_error_classifier.dart';

void main() {
  test('persists only a Firebase error category, not raw diagnostics', () {
    final error = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
      message: 'user uid and request path should never be persisted',
    );

    expect(
      classifyPersistedSyncError(error),
      'firebase:permission-denied',
    );
  });

  test('classifies network diagnostics without persisting the raw message', () {
    final error = StateError(
      'SocketException: connection refused to private-host.example/path',
    );

    expect(classifyPersistedSyncError(error), 'network');
  });

  test('classifies timeout exceptions', () {
    expect(
      classifyPersistedSyncError(
        TimeoutException('request payload contains private diagnostics'),
      ),
      'timeout',
    );
  });

  test('uses unknown for unrecognized exceptions', () {
    expect(
      classifyPersistedSyncError(
        StateError('internal object 123 with sensitive context'),
      ),
      'unknown',
    );
  });
}

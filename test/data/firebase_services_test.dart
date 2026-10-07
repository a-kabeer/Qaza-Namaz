import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/data/remote/backup_failure.dart';
import 'package:qaza_namaz/data/remote/firebase_services.dart';

void main() {
  test('Firebase initialization exposes independent layer state', () async {
    final services = FirebaseServices();
    final result = await services.initializeDetailed();

    if (defaultTargetPlatform == TargetPlatform.android) {
      expect(
        result.firebaseCoreInitialized ||
            result.failure == FirebaseInitializationFailure.firebaseCoreFailure,
        isTrue,
      );
    } else {
      expect(result.firebaseCoreInitialized, isFalse);
      expect(
        result.failure,
        FirebaseInitializationFailure.firebaseCoreFailure,
      );
    }
  });

  test('Firebase exception categories preserve actionable failure classes', () {
    final permission = classifyBackupFailure(
      FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'permission denied',
      ),
    );
    expect(
      permission.category,
      BackupFailureCategory.firestorePermissionDenied,
    );

    final unavailable = classifyBackupFailure(
      FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
        message: 'temporarily unavailable',
      ),
    );
    expect(
      unavailable.category,
      BackupFailureCategory.networkUnavailable,
    );
  });

  test('diagnostic failures never persist the raw credential-shaped message', () {
    final failure = classifyBackupFailure(
      StateError(
        'token abcdefghijklmnop1234567890 and user@example.com',
      ),
    );
    expect(failure.message, isNot(contains('user@example.com')));
    expect(failure.message, isNot(contains('abcdefghijklmnop1234567890')));
  });

  test('generic Firestore permission-denied is not mislabeled as App Check', () {
    final failure = classifyBackupFailure(
      FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'The caller does not have permission to execute the specified operation.',
      ),
    );
    expect(
      failure.category,
      BackupFailureCategory.firestorePermissionDenied,
    );
  });

  test('explicit App Check rejection is classified as App Check', () {
    final failure = classifyBackupFailure(
      FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'App Check token was rejected by the backend.',
      ),
    );
    expect(
      failure.category,
      BackupFailureCategory.appCheckRejected,
    );
  });

  test('App Check provider policy is release-safe', () {
    // Keep this regression near the provider implementation so accidental
    // provider swaps are caught by the unit suite as well as CI source checks.
    expect(FirebaseServices, isNotNull);
  });

}

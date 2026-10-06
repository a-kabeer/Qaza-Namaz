import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';

import '../../core/diagnostics/diagnostics.dart';

enum BackupFailureCategory {
  firebaseInitializationFailed,
  appCheckInitializationFailed,
  appCheckTokenUnavailable,
  authenticationUnavailable,
  authenticationUidMismatch,
  networkUnavailable,
  firestorePermissionDenied,
  firestoreUnauthenticated,
  firestoreNotFound,
  cloudGenerationMismatch,
  cloudDatasetInvalidState,
  firestoreTransactionFailed,
  backupDataSerializationFailed,
  unknown,
}

class BackupFailure implements Exception {
  const BackupFailure({
    required this.category,
    required this.message,
    this.cause,
    this.stackTrace,
  });

  final BackupFailureCategory category;
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() => message;
}

BackupFailure classifyBackupFailure(
  Object error, {
  StackTrace? stackTrace,
}) {
  if (error is BackupFailure) return error;

  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
        return BackupFailure(
          category: BackupFailureCategory.firestorePermissionDenied,
          message: _safeTechnicalMessage(error),
          cause: error,
          stackTrace: stackTrace,
        );
      case 'unauthenticated':
        return BackupFailure(
          category: BackupFailureCategory.firestoreUnauthenticated,
          message: _safeTechnicalMessage(error),
          cause: error,
          stackTrace: stackTrace,
        );
      case 'not-found':
        return BackupFailure(
          category: BackupFailureCategory.firestoreNotFound,
          message: _safeTechnicalMessage(error),
          cause: error,
          stackTrace: stackTrace,
        );
      case 'unavailable':
      case 'deadline-exceeded':
        return BackupFailure(
          category: BackupFailureCategory.networkUnavailable,
          message: _safeTechnicalMessage(error),
          cause: error,
          stackTrace: stackTrace,
        );
      case 'aborted':
      case 'failed-precondition':
      case 'already-exists':
        return BackupFailure(
          category: BackupFailureCategory.firestoreTransactionFailed,
          message: _safeTechnicalMessage(error),
          cause: error,
          stackTrace: stackTrace,
        );
      }
  }

  if (error is SocketException || error is TimeoutException) {
    return BackupFailure(
      category: BackupFailureCategory.networkUnavailable,
      message: _safeTechnicalMessage(error),
      cause: error,
      stackTrace: stackTrace,
    );
  }

  if (error is FormatException || error is JsonUnsupportedObjectError) {
    return BackupFailure(
      category: BackupFailureCategory.backupDataSerializationFailed,
      message: _safeTechnicalMessage(error),
      cause: error,
      stackTrace: stackTrace,
    );
  }

  final text = error.toString().toLowerCase();
  if (text.contains('cloud generation mismatch') ||
      text.contains('generation changed')) {
    return BackupFailure(
      category: BackupFailureCategory.cloudGenerationMismatch,
      message: _safeTechnicalMessage(error),
      cause: error,
      stackTrace: stackTrace,
    );
  }
  if (text.contains('dataset') &&
      (text.contains('deleting') ||
          text.contains('deleted') ||
          text.contains('not writable') ||
          text.contains('invalid state'))) {
    return BackupFailure(
      category: BackupFailureCategory.cloudDatasetInvalidState,
      message: _safeTechnicalMessage(error),
      cause: error,
      stackTrace: stackTrace,
    );
  }
  if (text.contains('firebase') && text.contains('unavailable')) {
    return BackupFailure(
      category: BackupFailureCategory.firebaseInitializationFailed,
      message: _safeTechnicalMessage(error),
      cause: error,
      stackTrace: stackTrace,
    );
  }

  return BackupFailure(
    category: BackupFailureCategory.unknown,
    message: _safeTechnicalMessage(error),
    cause: error,
    stackTrace: stackTrace,
  );
}

String _safeTechnicalMessage(Object error) =>
    redactDiagnosticMessage(error.toString()) ?? error.runtimeType.toString();

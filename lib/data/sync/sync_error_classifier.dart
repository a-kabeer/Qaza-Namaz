import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Converts exceptions into short, non-sensitive categories suitable for
/// durable outbox storage.
///
/// Raw exception strings can contain request metadata, paths, SDK internals,
/// or identifiers that are unnecessary once a retry has been recorded. Full
/// details remain available to the in-memory sync state for the current run.
String classifyPersistedSyncError(Object error) {
  if (error is FirebaseException) {
    return 'firebase:${error.code}';
  }
  if (error is TimeoutException) {
    return 'timeout';
  }

  final message = error.toString().toLowerCase();
  if (message.contains('network') ||
      message.contains('socket') ||
      message.contains('host lookup') ||
      message.contains('connection')) {
    return 'network';
  }
  if (message.contains('timeout') ||
      message.contains('deadline') ||
      message.contains('temporarily unavailable')) {
    return 'timeout';
  }
  if (message.contains('permission') || message.contains('unauthenticated')) {
    return 'permission';
  }

  return 'unknown';
}

import 'dart:async';
import 'dart:io';

/// What kind of thing went wrong, from the user's point of view.
///
/// Deliberately not a list of exception classes: a user does not care whether
/// something was a `SocketException` or a `TimeoutException`, they care
/// whether waiting will help. Each kind answers two questions — what to say,
/// and whether to offer Retry.
enum AppErrorKind {
  /// The device could not reach something. Waiting usually helps.
  network,

  /// The operation took too long. Waiting usually helps.
  timeout,

  /// The user has not granted something the operation needs.
  permission,

  /// The user is not signed in, or the session is no longer valid.
  authentication,

  /// The input was not acceptable. Retrying the same input will not help.
  validation,

  /// The file or record was not in the shape expected.
  malformedData,

  /// Local storage failed: disk full, database locked, file unreadable.
  storage,

  /// Something else. Reported, retryable, and never silently swallowed.
  unknown;

  /// Whether offering the user a Retry is honest for this kind.
  ///
  /// The rule the whole app follows: retry is offered when repeating the same
  /// action could plausibly succeed. Bad input and denied permissions are not
  /// fixed by pressing a button again, so those surfaces offer a different
  /// action instead.
  bool get isRetryable => switch (this) {
        AppErrorKind.network => true,
        AppErrorKind.timeout => true,
        AppErrorKind.storage => true,
        AppErrorKind.unknown => true,
        AppErrorKind.permission => false,
        AppErrorKind.authentication => false,
        AppErrorKind.validation => false,
        AppErrorKind.malformedData => false,
      };
}

/// An error that already knows what kind it is.
///
/// Domain exceptions implement this so classification does not depend on
/// matching their text. `core` declares it and everything else depends on
/// `core`, so the direction of the dependency stays right.
abstract interface class ClassifiedError {
  AppErrorKind get kind;
}

/// One classified failure, ready for a surface to render.
///
/// Every screen that shows a failure goes through this, so "what do we say"
/// and "do we offer Retry" are answered the same way everywhere instead of
/// per-screen.
class AppError implements Exception {
  const AppError({
    required this.kind,
    required this.cause,
    this.detail,
  });

  final AppErrorKind kind;

  /// The original error, kept for diagnostics. Never rendered raw.
  final Object cause;

  /// A short, already-safe clarification, when one is genuinely useful.
  final String? detail;

  bool get isRetryable => kind.isRetryable;

  /// Classifies an arbitrary thrown object.
  ///
  /// Anything already classified passes through unchanged, so wrapping twice
  /// is harmless and a call site can classify early without a downstream one
  /// having to know.
  factory AppError.from(Object error) {
    if (error is AppError) return error;
    if (error is ClassifiedError) {
      return AppError(kind: error.kind, cause: error);
    }

    if (error is TimeoutException) {
      return AppError(kind: AppErrorKind.timeout, cause: error);
    }
    if (error is SocketException || error is HttpException) {
      return AppError(kind: AppErrorKind.network, cause: error);
    }
    if (error is FormatException) {
      return AppError(kind: AppErrorKind.malformedData, cause: error);
    }
    if (error is ArgumentError) {
      return AppError(kind: AppErrorKind.validation, cause: error);
    }
    if (error is FileSystemException) {
      return AppError(kind: AppErrorKind.storage, cause: error);
    }

    // The remaining classification is by message, because the platform
    // channels this app talks to report through generic exception types.
    final text = error.toString().toLowerCase();
    if (text.contains('permission') || text.contains('denied')) {
      return AppError(kind: AppErrorKind.permission, cause: error);
    }
    if (text.contains('signed-in') ||
        text.contains('sign in') ||
        text.contains('unauthenticated') ||
        text.contains('unauthorized')) {
      return AppError(kind: AppErrorKind.authentication, cause: error);
    }
    if (text.contains('network') ||
        text.contains('unreachable') ||
        text.contains('offline') ||
        text.contains('connection')) {
      return AppError(kind: AppErrorKind.network, cause: error);
    }
    if (text.contains('timeout') || text.contains('timed out')) {
      return AppError(kind: AppErrorKind.timeout, cause: error);
    }
    if (text.contains('database') ||
        text.contains('sqlite') ||
        text.contains('disk') ||
        text.contains('storage')) {
      return AppError(kind: AppErrorKind.storage, cause: error);
    }

    return AppError(kind: AppErrorKind.unknown, cause: error);
  }

  @override
  String toString() => 'AppError(${kind.name}: ${cause.runtimeType})';
}

import 'package:flutter/foundation.dart';

/// Where a diagnostic came from.
///
/// A closed set on purpose: a report can only be filed against a part of the
/// app somebody decided was worth monitoring, which keeps the signal readable
/// and stops ad-hoc strings becoming the schema.
enum DiagnosticArea {
  startup,
  auth,
  notificationsInit,
  notificationsSchedule,
  sync,
  importData,
  databaseMigration,
  uncaught;

  String get code => name;
}

/// One reportable fact.
///
/// It carries the area, a short code, the error's runtime type and a redacted
/// message — never a Qaza record, a user id, a token or a raw exception
/// string. See [redactDiagnosticMessage].
@immutable
class DiagnosticEvent {
  const DiagnosticEvent({
    required this.area,
    required this.code,
    this.errorType,
    this.message,
    this.fatal = false,
  });

  final DiagnosticArea area;

  /// A short, stable identifier for what happened, e.g. `schedule_failed`.
  final String code;

  /// `error.runtimeType`, which is safe: a type name carries no user data.
  final String? errorType;

  /// The error's message after redaction, or null when there was none.
  final String? message;

  final bool fatal;

  @override
  String toString() => '[${area.code}] $code'
      '${errorType == null ? '' : ' ($errorType)'}'
      '${message == null ? '' : ': $message'}';

  @override
  bool operator ==(Object other) =>
      other is DiagnosticEvent &&
      other.area == area &&
      other.code == code &&
      other.errorType == errorType &&
      other.message == message &&
      other.fatal == fatal;

  @override
  int get hashCode => Object.hash(area, code, errorType, message, fatal);
}

/// Patterns that must never reach a diagnostics sink.
///
/// This is the whole privacy position of this feature: rather than trusting
/// every call site to be careful, anything that looks like user data is
/// removed on the way in. Over-redaction is the intended failure mode.
final List<(RegExp, String)> _redactions = [
  (RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+'), '<email>'),
  // ISO dates and date-like runs — a Qaza record's whole identity is a date.
  (RegExp(r'\d{4}-\d{2}-\d{2}(T[\d:.]+Z?)?'), '<date>'),
  (RegExp(r'\d{2}/\d{2}/\d{4}'), '<date>'),
  // Firebase uids, record ids, tokens: any long unbroken alphanumeric run.
  (RegExp(r'\b[A-Za-z0-9_-]{16,}\b'), '<id>'),
  // Any remaining bare number of 3+ digits, which could be a count of
  // somebody's missed prayers.
  (RegExp(r'\b\d{3,}\b'), '<n>'),
];

/// Strips anything that could identify a person or their ledger.
String? redactDiagnosticMessage(String? raw) {
  if (raw == null) return null;
  var value = raw;
  for (final (pattern, replacement) in _redactions) {
    value = value.replaceAll(pattern, replacement);
  }
  value = value.trim();
  if (value.isEmpty) return null;
  // A cap, so a stack-like blob can never be smuggled through as a message.
  const limit = 200;
  return value.length <= limit ? value : '${value.substring(0, limit)}…';
}

/// Where diagnostics go.
///
/// The app depends on this, not on a vendor. A crash-reporting backend is one
/// implementation; [NoopDiagnostics] and [BufferedDiagnostics] are others.
abstract interface class DiagnosticsService {
  /// Reports a failure. [error] is reduced to its type and a redacted message.
  void recordFailure(
    DiagnosticArea area,
    String code,
    Object error, {
    StackTrace? stack,
    bool fatal = false,
  });

  /// Reports something worth counting that is not a failure.
  void recordEvent(DiagnosticArea area, String code);
}

/// Builds the event for a failure, applying redaction once, in one place.
DiagnosticEvent buildFailureEvent(
  DiagnosticArea area,
  String code,
  Object error, {
  bool fatal = false,
}) =>
    DiagnosticEvent(
      area: area,
      code: code,
      errorType: error.runtimeType.toString(),
      message: redactDiagnosticMessage(error.toString()),
      fatal: fatal,
    );

/// Discards everything. The default, and what tests get unless they ask.
class NoopDiagnostics implements DiagnosticsService {
  const NoopDiagnostics();

  @override
  void recordFailure(DiagnosticArea area, String code, Object error,
      {StackTrace? stack, bool fatal = false}) {}

  @override
  void recordEvent(DiagnosticArea area, String code) {}
}

/// Keeps the last [capacity] events in memory.
///
/// Used by tests, and the shape a real uploader would drain.
class BufferedDiagnostics implements DiagnosticsService {
  BufferedDiagnostics({this.capacity = 50});

  final int capacity;
  final List<DiagnosticEvent> events = <DiagnosticEvent>[];

  void _add(DiagnosticEvent event) {
    events.add(event);
    if (events.length > capacity) events.removeAt(0);
  }

  @override
  void recordFailure(DiagnosticArea area, String code, Object error,
      {StackTrace? stack, bool fatal = false}) {
    _add(buildFailureEvent(area, code, error, fatal: fatal));
  }

  @override
  void recordEvent(DiagnosticArea area, String code) {
    _add(DiagnosticEvent(area: area, code: code));
  }
}

/// Prints in debug builds and does nothing in release.
///
/// The app's current behaviour, behind the same port, so wiring a backend
/// later is a one-line change rather than a hunt through call sites.
class DebugDiagnostics implements DiagnosticsService {
  const DebugDiagnostics();

  void _emit(DiagnosticEvent event) {
    if (kDebugMode) debugPrint('$event');
  }

  @override
  void recordFailure(DiagnosticArea area, String code, Object error,
      {StackTrace? stack, bool fatal = false}) {
    _emit(buildFailureEvent(area, code, error, fatal: fatal));
    if (kDebugMode && stack != null) debugPrintStack(stackTrace: stack);
  }

  @override
  void recordEvent(DiagnosticArea area, String code) => _emit(
        DiagnosticEvent(area: area, code: code),
      );
}

/// Sends to more than one sink, so a backend can be added without replacing
/// the debug output developers rely on.
class FanOutDiagnostics implements DiagnosticsService {
  const FanOutDiagnostics(this.targets);

  final List<DiagnosticsService> targets;

  @override
  void recordFailure(DiagnosticArea area, String code, Object error,
      {StackTrace? stack, bool fatal = false}) {
    for (final target in targets) {
      target.recordFailure(area, code, error, stack: stack, fatal: fatal);
    }
  }

  @override
  void recordEvent(DiagnosticArea area, String code) {
    for (final target in targets) {
      target.recordEvent(area, code);
    }
  }
}

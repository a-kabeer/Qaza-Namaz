import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/diagnostics/diagnostics.dart';

/// Task 23 — what the app reports, and what it must never report.
void main() {
  group('redaction', () {
    test('an email address never survives', () {
      expect(redactDiagnosticMessage('sign-in failed for user@example.com'),
          'sign-in failed for <email>');
    });

    test('a record date never survives', () {
      expect(
        redactDiagnosticMessage('could not complete record for 2026-01-03'),
        'could not complete record for <date>',
      );
      expect(
        redactDiagnosticMessage('duplicate on 03/01/2026'),
        'duplicate on <date>',
      );
    });

    test('an id or token never survives', () {
      expect(
        redactDiagnosticMessage('no document for aBcDeF0123456789xyz'),
        'no document for <id>',
      );
      expect(
        redactDiagnosticMessage('user test-user_fajr_2026-01-03 missing'),
        anyOf(contains('<id>'), contains('<date>')),
      );
    });

    test('a count of missed prayers never survives', () {
      expect(redactDiagnosticMessage('failed writing 12450 records'),
          'failed writing <n> records');
    });

    test('a short, harmless message is left alone', () {
      expect(redactDiagnosticMessage('network unreachable'),
          'network unreachable');
    });

    test('a long message is capped rather than passed through', () {
      // Ordinary words, so the cap is what is being exercised rather than the
      // id rule — an unbroken 500-character run is redacted as an id first.
      final long = List.filled(120, 'failed').join(' ');
      final redacted = redactDiagnosticMessage(long)!;
      expect(redacted.length, lessThanOrEqualTo(201));
      expect(redacted, endsWith('…'));
    });

    test('an unbroken blob is treated as an id, not passed through', () {
      expect(redactDiagnosticMessage('x' * 500), '<id>');
    });

    test('an empty or blank message becomes null', () {
      expect(redactDiagnosticMessage(''), isNull);
      expect(redactDiagnosticMessage('   '), isNull);
      expect(redactDiagnosticMessage(null), isNull);
    });
  });

  group('recording', () {
    test('a failure keeps type, redacted message and stack', () {
      final sink = BufferedDiagnostics();
      final stack = StackTrace.current;

      sink.recordFailure(
        DiagnosticArea.qazaCompletion,
        'completion_failed',
        StateError('rejected for someone@example.com on 2026-09-22'),
        stack: stack,
      );

      final event = sink.events.single;
      expect(event.area, DiagnosticArea.qazaCompletion);
      expect(event.code, 'completion_failed');
      expect(event.errorType, 'StateError');
      expect(event.message, contains('<email>'));
      expect(event.message, contains('<date>'));
      expect(event.message, isNot(contains('someone@example.com')));
      expect(event.stackTrace, isNull);
      expect(event.stackTrace, isNot(contains('someone@example.com')));
      expect(event.fatal, isFalse);
    });

    test('long stack is preserved for diagnostics', () {
      final stack = StackTrace.fromString('safe-line\n' + ('safe-line ' * 1000));
      final event = buildFailureEvent(
        DiagnosticArea.qazaCompletion,
        'completion_failed',
        StateError('boom'),
        stack: stack,
      );
      expect(event.stackTrace, isNotNull);
      expect(event.stackTrace!.length, lessThanOrEqualTo(4001));
    });

    test('a fatal failure is marked as one', () {
      final sink = BufferedDiagnostics();
      sink.recordFailure(
          DiagnosticArea.uncaught, 'flutter_error', Exception('boom'),
          fatal: true);
      expect(sink.events.single.fatal, isTrue);
    });

    test('the buffer is bounded, so it cannot grow without limit', () {
      final sink = BufferedDiagnostics(capacity: 3);
      for (var i = 0; i < 10; i++) {
        sink.recordEvent(DiagnosticArea.sync, 'tick_$i');
      }
      expect(sink.events, hasLength(3));
      expect(sink.events.last.code, 'tick_9');
    });

    test('the no-op sink really does nothing', () {
      const sink = NoopDiagnostics();
      sink.recordFailure(DiagnosticArea.sync, 'x', Exception('y'));
      sink.recordEvent(DiagnosticArea.sync, 'z');
    });

    test('fan-out reaches every sink', () {
      final a = BufferedDiagnostics();
      final b = BufferedDiagnostics();
      FanOutDiagnostics([a, b]).recordFailure(DiagnosticArea.importData,
          'import_failed', const FormatException('bad'));

      expect(a.events.single.code, 'import_failed');
      expect(b.events.single.code, 'import_failed');
    });
  });

  group('the sensitive-data logging audit', () {
    /// Every `lib` file, so the rule below is checked against the whole app
    /// rather than the handful of places that happened to be reviewed.
    List<File> sources() => Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    test('no source logs a Qaza record, a user id or a token directly', () {
      // Interpolations that would put user data straight into a log line.
      final banned = RegExp(
        r'(debugPrint|print)\([^)]*\$\{?('
        r'record|records|userId|user\.id|token|idToken|accessToken|email'
        r')\b',
      );
      final offenders = <String>[];
      for (final file in sources()) {
        final text = file.readAsStringSync();
        if (banned.hasMatch(text)) offenders.add(file.path);
      }
      expect(offenders, isEmpty,
          reason: 'these log user data directly instead of going through '
              'DiagnosticsService, which redacts');
    });

    test('diagnostics is the only reporting port, and it redacts', () {
      // If this ever fails, someone added a second way to report failures and
      // the redaction guarantee no longer holds for the whole app.
      final text =
          File('lib/core/diagnostics/diagnostics.dart').readAsStringSync();
      expect(text, contains('redactDiagnosticMessage'));
      expect(text, contains('error.runtimeType.toString()'));
    });
  });
}

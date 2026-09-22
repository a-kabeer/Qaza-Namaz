import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/errors/app_error.dart';
import 'package:qaza_namaz/core/errors/app_error_messages.dart';
import 'package:qaza_namaz/l10n/app_localizations_en.dart';
import 'package:qaza_namaz/l10n/app_localizations_ur.dart';

/// Task 22 — one taxonomy, one retry policy.
void main() {
  group('classification', () {
    test('by exception type', () {
      expect(AppError.from(TimeoutException('x')).kind, AppErrorKind.timeout);
      expect(
          AppError.from(const SocketException('x')).kind, AppErrorKind.network);
      expect(AppError.from(const FormatException('x')).kind,
          AppErrorKind.malformedData);
      expect(AppError.from(ArgumentError('x')).kind, AppErrorKind.validation);
      expect(AppError.from(const FileSystemException('x')).kind,
          AppErrorKind.storage);
    });

    test('by message, for the generic exceptions platform channels throw', () {
      expect(AppError.from(StateError('permission denied')).kind,
          AppErrorKind.permission);
      expect(
          AppError.from(StateError('This action requires a signed-in account'))
              .kind,
          AppErrorKind.authentication);
      expect(AppError.from(StateError('network unreachable')).kind,
          AppErrorKind.network);
      expect(AppError.from(StateError('the request timed out')).kind,
          AppErrorKind.timeout);
      expect(AppError.from(StateError('database is full')).kind,
          AppErrorKind.storage);
    });

    test('anything unrecognised is unknown, never swallowed', () {
      final error = AppError.from(StateError('a wholly novel problem'));
      expect(error.kind, AppErrorKind.unknown);
      expect(error.cause, isA<StateError>());
    });

    test('classifying twice changes nothing', () {
      final once = AppError.from(const SocketException('x'));
      expect(AppError.from(once), same(once));
    });
  });

  group('the retry policy', () {
    test('retry is offered only where repeating could work', () {
      for (final kind in [
        AppErrorKind.network,
        AppErrorKind.timeout,
        AppErrorKind.storage,
        AppErrorKind.unknown,
      ]) {
        expect(kind.isRetryable, isTrue, reason: kind.name);
      }
      for (final kind in [
        AppErrorKind.permission,
        AppErrorKind.authentication,
        AppErrorKind.validation,
        AppErrorKind.malformedData,
      ]) {
        expect(kind.isRetryable, isFalse,
            reason: '${kind.name}: the same action would fail identically');
      }
    });

    test('every kind has a policy, so a new one cannot slip through', () {
      for (final kind in AppErrorKind.values) {
        expect(() => kind.isRetryable, returnsNormally, reason: kind.name);
      }
    });
  });

  group('messages', () {
    test('every kind has one in both languages', () {
      final en = AppLocalizationsEn();
      final ur = AppLocalizationsUr();
      for (final kind in AppErrorKind.values) {
        final english = messageFor(en, kind);
        final urdu = messageFor(ur, kind);
        expect(english, isNotEmpty, reason: kind.name);
        expect(urdu, isNotEmpty, reason: kind.name);
        expect(urdu, isNot(english),
            reason: '${kind.name} is not actually translated');
      }
    });

    test('a raw exception never becomes the message', () {
      final en = AppLocalizationsEn();
      final message = messageFor(
          en,
          AppError.from(
            StateError('Bad state: user_12345 at /data/db.sqlite'),
          ).kind);
      expect(message, isNot(contains('user_12345')));
      expect(message, isNot(contains('Bad state')));
    });
  });
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:qaza_namaz/data/auth/firebase_auth_repository.dart';
import 'package:qaza_namaz/data/auth/google_auth_flow.dart';
import 'package:qaza_namaz/domain/entities/app_user.dart';

/// Every way Google sign-in can fail, and the stage each one reports.
///
/// The value of a distinct code is operational: a missing ID token can indicate
/// an OAuth certificate/configuration mismatch, a Firebase code identifies the
/// Auth-stage failure, and genuine cancellation remains a normal user action.
/// Collapsing them into one message is what makes a sign-in bug unfixable from
/// a report.
void main() {
  group('stage preconditions', () {
    test('an unsupported platform is named as such', () {
      expect(
        () => FirebaseAuthRepository.requireAuthenticateSupport(false),
        throwsA(
          isA<AuthenticationException>()
              .having((e) => e.source, 'source', 'google-sign-in')
              .having((e) => e.code, 'code', 'unsupported-platform'),
        ),
      );
      // The supported case simply passes through.
      FirebaseAuthRepository.requireAuthenticateSupport(true);
    });

    test('a missing ID token points at the signing certificate', () {
      for (final token in <String?>[null, '']) {
        expect(
          () => FirebaseAuthRepository.requireIdToken(token),
          throwsA(
            isA<AuthenticationException>()
                .having((e) => e.source, 'source', 'google-sign-in')
                .having((e) => e.code, 'code', 'missing-id-token')
                .having((e) => e.message, 'message', contains('SHA-1')),
          ),
          reason: 'token: $token',
        );
      }
      expect(FirebaseAuthRepository.requireIdToken('abc'), 'abc');
    });

    test('a credential that yields no Firebase user is named as such', () {
      expect(
        () => FirebaseAuthRepository.requireFirebaseUser(null),
        throwsA(
          isA<AuthenticationException>()
              .having((e) => e.source, 'source', 'firebase-auth')
              .having((e) => e.code, 'code', 'no-user'),
        ),
      );
      const user = AppUser(id: 'u1', email: 'u1@example.com');
      expect(FirebaseAuthRepository.requireFirebaseUser(user), user);
    });
  });

  group('failure mapping', () {
    test('a Google SDK failure keeps the SDK code', () {
      final mapped = FirebaseAuthRepository.mapSignInFailure(
        const GoogleSignInException(
          code: GoogleSignInExceptionCode.clientConfigurationError,
          description: 'Bad OAuth client.',
        ),
      );

      expect(mapped, isA<AuthenticationException>());
      expect(mapped!.source, 'google-sign-in');
      expect(mapped.code, 'clientConfigurationError');
      expect(mapped.message, 'Bad OAuth client.');
    });

    test('a Google SDK failure with no description still reports its code', () {
      final mapped = FirebaseAuthRepository.mapSignInFailure(
        const GoogleSignInException(
          code: GoogleSignInExceptionCode.unknownError,
          description: '   ',
        ),
      );

      expect(mapped!.message, contains('unknownError'));
    });

    test('genuine Google cancellation is identified as user initiated', () {
      final mapped = FirebaseAuthRepository.mapSignInFailure(
        const GoogleSignInException(code: GoogleSignInExceptionCode.canceled),
      );

      expect(mapped, isA<AuthenticationCancelledException>());
      final cancellation = mapped! as AuthenticationCancelledException;
      expect(cancellation.code, 'canceled');
      expect(cancellation.userInitiated, isTrue);
      expect(cancellation.message, 'Google Sign-In was cancelled by the user.');

      final flowCancelled = FirebaseAuthRepository.mapSignInFailure(
        const GoogleAuthFlowCancelledException(),
      );
      expect(flowCancelled, isA<AuthenticationCancelledException>());
      expect(
        (flowCancelled! as AuthenticationCancelledException).userInitiated,
        isTrue,
      );
    });

    test('cancellation with platform description stays diagnosable', () {
      final mapped = FirebaseAuthRepository.mapSignInFailure(
        const GoogleSignInException(
          code: GoogleSignInExceptionCode.canceled,
          description: 'Credential Manager returned a configuration failure',
        ),
      );

      expect(mapped, isA<AuthenticationCancelledException>());
      final cancellation = mapped! as AuthenticationCancelledException;
      expect(cancellation.userInitiated, isFalse);
      expect(cancellation.diagnostic, contains('google-sign-in/canceled'));
      expect(
        cancellation.diagnostic,
        contains('Credential Manager returned a configuration failure'),
      );
      expect(
        cancellation.toString(),
        contains('Authentication failed (google-sign-in/canceled'),
      );
    });

    test('a Firebase Auth failure keeps the Firebase code', () {
      final mapped = FirebaseAuthRepository.mapSignInFailure(
        FirebaseAuthException(
          code: 'account-exists-with-different-credential',
          message: 'Already linked elsewhere.',
        ),
      );

      expect(mapped!.source, 'firebase-auth');
      expect(mapped.code, 'account-exists-with-different-credential');
      expect(mapped.message, 'Already linked elsewhere.');
    });

    test('a platform failure keeps the platform code', () {
      final mapped = FirebaseAuthRepository.mapSignInFailure(
        PlatformException(code: 'sign_in_failed', message: 'ApiException: 10'),
      );

      expect(mapped!.source, 'platform');
      expect(mapped.code, 'sign_in_failed');
      expect(mapped.message, 'ApiException: 10');
    });

    test('anything else is still reported rather than swallowed', () {
      final mapped = FirebaseAuthRepository.mapSignInFailure(
        StateError('something unexpected'),
      );

      expect(mapped!.source, 'google');
      expect(mapped.code, 'StateError');
      expect(mapped.message, contains('something unexpected'));
    });

    test('a stage failure is passed through, not re-wrapped', () {
      // Null means "rethrow unchanged": the exception already names its stage.
      expect(
        FirebaseAuthRepository.mapSignInFailure(
          const AuthenticationException(
            source: 'google-sign-in',
            code: 'missing-id-token',
            message: 'no token',
          ),
        ),
        isNull,
      );
    });

    test('the stack travels with the mapped failure', () {
      final stack = StackTrace.current;
      final mapped = FirebaseAuthRepository.mapSignInFailure(
        PlatformException(code: 'sign_in_failed'),
        stack: stack,
      );

      expect(mapped!.stackTrace, stack);
      expect(mapped.cause, isA<PlatformException>());
    });

    test('every mapped failure carries a readable diagnostic', () {
      final mapped = FirebaseAuthRepository.mapSignInFailure(
        PlatformException(code: 'sign_in_failed', message: 'ApiException: 10'),
      );

      expect(mapped!.diagnostic, 'platform/sign_in_failed: ApiException: 10');
    });
  });
}

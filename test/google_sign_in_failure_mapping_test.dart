import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:qaza_namaz/data/auth/firebase_auth_repository.dart';

void main() {
  group('Google sign-in failure mapping', () {
    test('preserves Google client configuration code and description', () {
      const raw = GoogleSignInException(
        code: GoogleSignInExceptionCode.clientConfigurationError,
        description: 'serverClientId is invalid for this Android app',
      );

      final mapped = FirebaseAuthRepository.mapSignInFailure(raw);

      expect(mapped, isA<AuthenticationException>());
      expect(mapped!.source, 'google-sign-in');
      expect(mapped.code, 'clientConfigurationError');
      expect(
        mapped.message,
        'serverClientId is invalid for this Android app',
      );
    });

    test('preserves Google provider configuration code and description', () {
      const raw = GoogleSignInException(
        code: GoogleSignInExceptionCode.providerConfigurationError,
        description: 'Google Play services is unavailable or misconfigured',
      );

      final mapped = FirebaseAuthRepository.mapSignInFailure(raw);

      expect(mapped, isA<AuthenticationException>());
      expect(mapped!.code, 'providerConfigurationError');
      expect(mapped.message, contains('Google Play services'));
    });

    test('keeps a genuine cancellation silent when no description exists', () {
      const raw = GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
      );

      final mapped = FirebaseAuthRepository.mapSignInFailure(raw);

      expect(mapped, isA<AuthenticationCancelledException>());
      final cancellation = mapped! as AuthenticationCancelledException;
      expect(cancellation.userInitiated, isTrue);
      expect(cancellation.message, 'Google Sign-In was cancelled by the user.');
    });

    test('preserves a cancellation description for diagnosis', () {
      const raw = GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
        description: 'Credential Manager returned a configuration failure',
        details: 'provider unavailable',
      );

      final mapped = FirebaseAuthRepository.mapSignInFailure(raw);

      expect(mapped, isA<AuthenticationCancelledException>());
      final cancellation = mapped! as AuthenticationCancelledException;
      expect(cancellation.userInitiated, isFalse);
      expect(
        cancellation.message,
        'Credential Manager returned a configuration failure',
      );
    });

    test('maps Firebase Auth failures to firebase-auth stage', () {
      final raw = FirebaseAuthException(
        code: 'operation-not-allowed',
        message: 'Google sign-in provider is disabled',
      );

      final mapped = FirebaseAuthRepository.mapSignInFailure(raw);

      expect(mapped!.source, 'firebase-auth');
      expect(mapped.code, 'operation-not-allowed');
      expect(mapped.message, 'Google sign-in provider is disabled');
    });

    test('maps PlatformException failures to platform stage', () {
      const raw = PlatformException(
        code: 'credential_error',
        message: 'Credential Manager could not complete the request',
      );

      final mapped = FirebaseAuthRepository.mapSignInFailure(raw);

      expect(mapped!.source, 'platform');
      expect(mapped.code, 'credential_error');
      expect(
        mapped.message,
        'Credential Manager could not complete the request',
      );
    });

    test('missing ID token has a dedicated actionable failure', () {
      expect(
        () => FirebaseAuthRepository.requireIdToken(null),
        throwsA(
          isA<AuthenticationException>()
              .having((e) => e.source, 'source', 'google-sign-in')
              .having((e) => e.code, 'code', 'missing-id-token'),
        ),
      );
    });
  });
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:qaza_namaz/core/diagnostics/diagnostics.dart';
import 'package:qaza_namaz/data/auth/android_signing_identity.dart';
import 'package:qaza_namaz/data/auth/firebase_auth_repository.dart';
import 'package:qaza_namaz/data/auth/google_auth_config.dart';

/// One tap opens one account chooser.
///
/// On Android `GoogleSignIn.authenticate()` uses the button flow, so every
/// call puts a chooser in front of the user. An earlier fix for "[16] Account
/// reauth failed" cleared credential state and called `authenticate()` again;
/// that showed the chooser twice for a single tap and, when the cause was an
/// unregistered signing certificate, failed identically the second time.
class _FakeGoogleSignIn implements GoogleSignIn {
  _FakeGoogleSignIn({this.failure});

  /// Thrown by every `authenticate()` call.
  Object? failure;
  int authenticateCalls = 0;
  int signOutCalls = 0;
  bool supported = true;

  @override
  bool supportsAuthenticate() => supported;

  @override
  Future<void> initialize({
    String? clientId,
    String? serverClientId,
    String? nonce,
    String? hostedDomain,
  }) async {}

  @override
  Future<GoogleSignInAccount> authenticate({
    List<String> scopeHint = const <String>[],
  }) async {
    authenticateCalls++;
    throw failure ?? StateError('no outcome configured');
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('unexpected GoogleSignIn member: '
          '${invocation.memberName}');
}

class _FakeFirebaseAuth implements FirebaseAuth {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('unexpected FirebaseAuth member: '
          '${invocation.memberName}');
}

/// A signing identity the test dictates.
class _StubSigningIdentity implements AndroidSigningIdentityService {
  _StubSigningIdentity(this.identity, {this.failure});

  final AndroidSigningIdentity? identity;
  final Object? failure;
  int reads = 0;

  @override
  Future<AndroidSigningIdentity?> read() async {
    reads++;
    final error = failure;
    if (error != null) throw error;
    return identity;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  const reauthFailure = '[16] Account reauth failed.';
  const registeredSha1 = '3ab6c8b508a68579254d31983716f5d2babd418d';

  late _FakeGoogleSignIn google;
  late BufferedDiagnostics diagnostics;

  setUp(() {
    google = _FakeGoogleSignIn();
    diagnostics = BufferedDiagnostics(capacity: 50);
  });

  FirebaseAuthRepository repository({
    AndroidSigningIdentity? identity,
    Object? identityFailure,
  }) =>
      FirebaseAuthRepository(
        auth: _FakeFirebaseAuth(),
        googleSignIn: google,
        diagnostics: diagnostics,
        signingIdentity: _StubSigningIdentity(
          identity,
          failure: identityFailure,
        ),
      );

  AndroidSigningIdentity identityWith({
    String package = googleAndroidApplicationId,
    String sha1 = registeredSha1,
  }) =>
      AndroidSigningIdentity(
        packageName: package,
        sha1Fingerprints: [sha1],
        sha256Fingerprints: const ['f68891'],
      );

  group('the account chooser', () {
    test('opens exactly once on a [16] Account reauth failed', () async {
      google.failure = const GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
        description: reauthFailure,
      );

      await expectLater(
        repository().authenticateOnce(),
        throwsA(isA<GoogleSignInException>()),
      );

      expect(google.authenticateCalls, 1,
          reason: 'a second authenticate() is a second account chooser');
    });

    test('stale credential state is still cleared, without any UI', () async {
      google.failure = const GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
        description: reauthFailure,
      );

      await expectLater(
        repository().authenticateOnce(),
        throwsA(isA<GoogleSignInException>()),
      );

      expect(google.signOutCalls, 1,
          reason: 'clearCredentialState() makes the next attempt start clean');
      expect(google.authenticateCalls, 1);
    });

    test('opens exactly once on an ordinary cancellation', () async {
      google.failure = const GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
      );

      await expectLater(
        repository().authenticateOnce(),
        throwsA(isA<GoogleSignInException>()),
      );

      expect(google.authenticateCalls, 1);
      expect(google.signOutCalls, 0,
          reason: 'a plain cancellation leaves credential state alone');
    });

    test('opens exactly once on any other failure', () async {
      google.failure = const GoogleSignInException(
        code: GoogleSignInExceptionCode.clientConfigurationError,
        description: 'bad client',
      );

      await expectLater(
        repository().authenticateOnce(),
        throwsA(isA<GoogleSignInException>()),
      );

      expect(google.authenticateCalls, 1);
      expect(google.signOutCalls, 0);
    });

    test('the original failure is never replaced by the recovery', () async {
      google.failure = const GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
        description: reauthFailure,
      );

      await expectLater(
        repository().authenticateOnce(),
        throwsA(
          isA<GoogleSignInException>()
              .having((e) => e.description, 'description', reauthFailure),
        ),
      );
    });
  });

  group('[16] is not a cancellation', () {
    test('it maps to its own stage, not to canceled', () {
      final mapped = FirebaseAuthRepository.mapSignInFailure(
        const GoogleSignInException(
          code: GoogleSignInExceptionCode.canceled,
          description: reauthFailure,
        ),
      );

      expect(mapped, isA<AuthenticationException>());
      expect(mapped, isNot(isA<AuthenticationCancelledException>()),
          reason: 'every `on AuthenticationCancelledException` handler in the '
              'app would otherwise treat a config failure as "never mind"');
      expect(mapped!.source, 'google-sign-in');
      expect(mapped.code, 'account-reauth-failed');
      expect(mapped.message, contains('not a cancellation'));
      expect(mapped.message, contains('SHA-1'));
    });

    test('a genuine cancellation still is one', () {
      expect(
        FirebaseAuthRepository.mapSignInFailure(
          const GoogleSignInException(
            code: GoogleSignInExceptionCode.canceled,
          ),
        ),
        isA<AuthenticationCancelledException>(),
      );
    });
  });

  group('an unusable build never reaches the chooser', () {
    test('an unregistered certificate is refused, with its fingerprint',
        () async {
      const wrong = 'abababababababababababababababababababab';

      await expectLater(
        repository(identity: identityWith(sha1: wrong))
            .requireRegisteredBuild(),
        throwsA(
          isA<AuthenticationException>()
              .having((e) => e.source, 'source', 'android-signing')
              .having((e) => e.code, 'code', 'unregistered-certificate')
              .having((e) => e.message, 'message', contains(wrong)),
        ),
      );
      expect(google.authenticateCalls, 0,
          reason: 'opening a chooser that cannot succeed wastes the user');
    });

    test('a mismatched package is refused separately', () async {
      await expectLater(
        repository(identity: identityWith(package: 'com.other.app'))
            .requireRegisteredBuild(),
        throwsA(
          isA<AuthenticationException>()
              .having((e) => e.code, 'code', 'unexpected-package')
              .having((e) => e.message, 'message', contains('com.other.app')),
        ),
      );
    });

    test('a registered build proceeds', () async {
      await repository(identity: identityWith()).requireRegisteredBuild();
    });

    test('a platform that cannot answer blocks nothing', () async {
      await repository(identity: null).requireRegisteredBuild();
    });

    test('a failed introspection blocks nothing, but is recorded', () async {
      await repository(
        identityFailure: StateError('channel exploded'),
      ).requireRegisteredBuild();

      expect(
        diagnostics.events.map((e) => e.code),
        contains('signing_identity_unavailable'),
      );
    });
  });
}

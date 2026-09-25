import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/diagnostics/diagnostics.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import 'android_signing_identity.dart';
import 'google_auth_flow.dart';
import 'google_auth_config.dart';

class AuthenticationException implements Exception {
  const AuthenticationException({
    required this.source,
    required this.code,
    required this.message,
    this.cause,
    this.stackTrace,
  });

  final String source;
  final String code;
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  String get diagnostic => '$source/$code: $message';

  @override
  String toString() => 'Authentication failed ($diagnostic)';
}

class AuthenticationCancelledException extends AuthenticationException {
  const AuthenticationCancelledException()
      : this._(
          userInitiated: true,
          message: 'Google Sign-In was cancelled by the user.',
        );

  factory AuthenticationCancelledException.withDescription(
    String description,
  ) =>
      AuthenticationCancelledException._(
        userInitiated: false,
        message: description.trim(),
      );

  const AuthenticationCancelledException._({
    required this.userInitiated,
    required String message,
  }) : super(
          source: 'google-sign-in',
          code: 'canceled',
          message: message,
        );

  /// True only when the platform gives us no indication of another cause.
  ///
  /// google_sign_in documents [canceled] as user cancellation. When the
  /// platform supplies a description, preserve it because it may contain
  /// actionable information about the failure.
  final bool userInitiated;

  @override
  String toString() => userInitiated
      ? message
      : 'Authentication failed ($diagnostic)';
}

class FirebaseAuthRepository implements AuthRepository, DetailedAuthRepository {
  FirebaseAuthRepository({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    DiagnosticsService diagnostics = const NoopDiagnostics(),
    AndroidSigningIdentityService signingIdentity =
        const AndroidSigningIdentityService(),
  })  : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
        _diagnostics = diagnostics,
        _signingIdentity = signingIdentity;

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final DiagnosticsService _diagnostics;
  final AndroidSigningIdentityService _signingIdentity;

  /// google_sign_in 7.x requires exactly one initialization before any other
  /// GoogleSignIn method is called. Kept lazy so constructing the repository
  /// never triggers platform work.
  Future<void>? _googleSignInInitialization;

  /// Initializes the Google SDK once, and only once, per successful attempt.
  ///
  /// The future is cached so concurrent callers share one initialization and a
  /// second sign-in never re-initializes. A *failed* attempt is uncached
  /// instead: caching it would make the first transient failure permanent for
  /// the life of the app, and every retry the user is offered would fail
  /// without ever reaching the platform again.
  Future<void> _ensureGoogleSignInInitialized() {
    final pending = _googleSignInInitialization;
    if (pending != null) return pending;

    final attempt = _googleSignIn
        .initialize()
        .catchError((Object error, StackTrace stack) {
      _googleSignInInitialization = null;
      Error.throwWithStackTrace(error, stack);
    });
    _googleSignInInitialization = attempt;
    return attempt;
  }

  @override
  AppUser? get currentUser => _mapUser(_auth.currentUser);

  @override
  Stream<AppUser?> authStateChanges() => _auth.authStateChanges().map(_mapUser);

  @override
  Future<AppUser> signInWithGoogle() async =>
      (await signInWithGoogleDetails()).user;

  @override
  Future<GoogleSignInResult> signInWithGoogleDetails() async {
    try {
      _validateFirebaseConfiguration();

      return await GoogleAuthFlow(
        beginGoogleSignIn: () async {
          await _ensureGoogleSignInInitialized();

          requireAuthenticateSupport(_googleSignIn.supportsAuthenticate());
          await requireRegisteredBuild();

          final googleUser = await authenticateOnce();
          final authentication = googleUser.authentication;
          return GoogleIdentityTokens(idToken: authentication.idToken);
        },
        signInToFirebase: (tokens) async {
          final idToken = requireIdToken(tokens.idToken);

          final credential = GoogleAuthProvider.credential(idToken: idToken);
          final result = await _auth.signInWithCredential(credential);
          final user = requireFirebaseUser(_mapUser(result.user));
          return GoogleSignInResult(
            user: user,
            isNewUser: result.additionalUserInfo?.isNewUser ?? false,
          );
        },
      ).signInWithDetails();
    } catch (error, stack) {
      final mapped = mapSignInFailure(error, stack: stack);

      // Preserve the original platform/Firebase failure in diagnostics before
      // any UI-friendly mapping occurs. Structured GoogleSignInException
      // fields such as code/description are essential when diagnosing the
      // Android OAuth/Credential Manager boundary.
      _debugLog(error, stack);

      // A failure that already knows which stage it came from travels
      // unchanged; re-wrapping it would bury the stage it names.
      if (mapped == null) rethrow;
      throw mapped;
    }
  }

  /// Runs the interactive Google flow exactly once per user action.
  ///
  /// On Android `authenticate()` uses the button flow, so every call puts an
  /// account chooser in front of the user. An earlier version of this code
  /// answered "[16] Account reauth failed" by clearing credential state and
  /// calling `authenticate()` again, which showed the chooser a second time
  /// for a single tap — and, when the cause was an unregistered signing
  /// certificate, failed identically the second time. One tap opens one
  /// chooser.
  ///
  /// The stale credential state is still worth clearing, because that is what
  /// makes the user's *next* deliberate attempt start clean. `signOut()` maps
  /// to `clearCredentialState()` on Android and shows no UI, so it is safe to
  /// do here; what is not safe is re-entering the interactive flow.
  @visibleForTesting
  Future<GoogleSignInAccount> authenticateOnce() async {
    try {
      return await _googleSignIn.authenticate();
    } on GoogleSignInException catch (error) {
      if (_isCredentialManagerReauthFailure(error.description)) {
        await _clearCredentialState();
      }
      rethrow;
    }
  }

  Future<void> _clearCredentialState() async {
    try {
      await _googleSignIn.signOut();
    } catch (error, stack) {
      // A recovery aid, never a reason to replace the original failure.
      _diagnostics.recordFailure(
        DiagnosticArea.auth,
        'credential_state_clear_failed',
        error,
        stack: stack,
      );
    }
  }

  /// Refuses to open an account chooser that cannot possibly succeed.
  ///
  /// Google Play services matches the caller by package name and signing
  /// certificate before it will mint an ID token. When this build is signed
  /// with a certificate no registered OAuth client knows, the chooser opens,
  /// the user picks an account, and the platform answers "[16] Account reauth
  /// failed" with nothing else to go on. Checking first turns that into a
  /// statement of exactly which fingerprint is missing.
  ///
  /// Enforcement is one-directional: only a definite mismatch stops the flow.
  /// A platform that cannot report its own identity is left alone.
  @visibleForTesting
  Future<void> requireRegisteredBuild() async {
    final AndroidSigningIdentity? identity;
    try {
      identity = await _signingIdentity.read();
    } catch (error, stack) {
      _diagnostics.recordFailure(
        DiagnosticArea.auth,
        'signing_identity_unavailable',
        error,
        stack: stack,
      );
      return;
    }
    if (identity == null) return;

    switch (checkAndroidSigningRegistration(identity)) {
      case AndroidSigningRegistration.registered:
      case AndroidSigningRegistration.unknown:
        return;
      case AndroidSigningRegistration.unexpectedPackage:
        throw AuthenticationException(
          source: 'android-signing',
          code: 'unexpected-package',
          message: 'This build reports package "${identity.packageName}", but '
              'the Firebase Android OAuth client is registered for '
              '"$googleAndroidApplicationId". Google Sign-In cannot match a '
              'caller whose package name differs.',
        );
      case AndroidSigningRegistration.unregisteredCertificate:
        throw AuthenticationException(
          source: 'android-signing',
          code: 'unregistered-certificate',
          message: 'This build is signed with SHA-1 '
              '${identity.sha1Fingerprints.join(", ")}, which is not '
              'registered as an Android OAuth client for '
              '"$googleAndroidApplicationId". Add it (and the matching '
              'SHA-256) to the Firebase console, download the updated '
              'google-services.json, and rebuild.',
        );
    }
  }

  /// The platform cannot run the interactive Google flow at all.
  @visibleForTesting
  static void requireAuthenticateSupport(bool supported) {
    if (supported) return;
    throw const AuthenticationException(
      source: 'google-sign-in',
      code: 'unsupported-platform',
      message:
          'Google Sign-In authentication is not supported on this platform.',
    );
  }

  /// Google finished, but handed back nothing Firebase can use.
  ///
  /// This is the signature of a signing certificate the Firebase project does
  /// not know: the account chooser completes normally and the ID token comes
  /// back null. It earns its own code because it is the one failure the user
  /// cannot do anything about and the developer can.
  @visibleForTesting
  static String requireIdToken(String? idToken) {
    if (idToken != null && idToken.isNotEmpty) return idToken;
    throw const AuthenticationException(
      source: 'google-sign-in',
      code: 'missing-id-token',
      message: 'Google Sign-In completed without an ID token. '
          'Check the Android OAuth client, SHA-1/SHA-256 fingerprints, '
          'package ID, and Firebase Google provider configuration.',
    );
  }

  /// Firebase accepted the credential but produced no user.
  @visibleForTesting
  static AppUser requireFirebaseUser(AppUser? user) {
    if (user != null) return user;
    throw const AuthenticationException(
      source: 'firebase-auth',
      code: 'no-user',
      message:
          'Firebase Authentication returned no user after Google credential '
          'sign-in.',
    );
  }

  /// Names the stage a raw sign-in failure came from.
  ///
  /// Returns null when [error] is already an [AuthenticationException], which
  /// means it carries its own stage and must be rethrown untouched.
  @visibleForTesting
  static AuthenticationException? mapSignInFailure(
    Object error, {
    StackTrace? stack,
  }) {
    if (error is GoogleSignInException) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        final description = error.description?.trim();
        if (description == null || description.isEmpty) {
          return const AuthenticationCancelledException();
        }
        if (_isCredentialManagerReauthFailure(description)) {
          // Play services reports this with CommonStatusCodes.CANCELED (16),
          // which is why it used to arrive dressed as a user cancellation. It
          // is not one: the user picked an account and the platform refused to
          // re-authenticate it. Giving it its own code keeps it out of every
          // `on AuthenticationCancelledException` handler in the app, which
          // would otherwise treat a configuration failure as "never mind".
          return AuthenticationException(
            source: 'google-sign-in',
            code: 'account-reauth-failed',
            message: 'Google Sign-In could not re-authenticate the selected '
                'account. This is not a cancellation. It usually means this '
                'build\'s package name and signing certificate SHA-1 are not '
                'registered as an Android OAuth client for this Firebase '
                'project; it can also mean the device account itself needs '
                'attention in Android Settings.',
            cause: error,
            stackTrace: stack,
          );
        }
        return AuthenticationCancelledException.withDescription(description);
      }

      return AuthenticationException(
        source: 'google-sign-in',
        code: error.code.name,
        message: _googleFailureMessage(error),
        cause: error,
        stackTrace: stack,
      );
    }
    if (error is GoogleAuthFlowCancelledException) {
      return const AuthenticationCancelledException();
    }
    if (error is AuthenticationException) return null;
    if (error is FirebaseAuthException) {
      return AuthenticationException(
        source: 'firebase-auth',
        code: error.code,
        message: _describe(error.message, error),
        cause: error,
        stackTrace: stack,
      );
    }
    if (error is PlatformException) {
      return AuthenticationException(
        source: 'platform',
        code: error.code,
        message: _describe(error.message, error),
        cause: error,
        stackTrace: stack,
      );
    }
    return AuthenticationException(
      source: 'google',
      code: error.runtimeType.toString(),
      message: error.toString(),
      cause: error,
      stackTrace: stack,
    );
  }

  static bool _isCredentialManagerReauthFailure(String? description) {
    final normalized = description?.toLowerCase() ?? '';
    return normalized.contains('[16]') &&
        normalized.contains('account reauth failed');
  }

  @visibleForTesting
  static bool isCredentialManagerReauthFailure(String? description) =>
      _isCredentialManagerReauthFailure(description);

  static String _googleFailureMessage(GoogleSignInException error) {
    final description = error.description?.trim();
    if (description != null && description.isNotEmpty) {
      return description;
    }

    // Keep GoogleSignInException.details out of the UI. The original exception
    // is already captured by diagnostics, where the redaction pipeline applies.
    return 'Google Sign-In failed with ${error.code.name}. '
        'See diagnostics for the underlying platform details.';
  }

  static String _describe(String? message, Object fallback) =>
      message != null && message.trim().isNotEmpty
          ? message
          : fallback.toString();

  void _validateFirebaseConfiguration() {
    final options = Firebase.app().options;

    if (options.projectId != googleFirebaseProjectId) {
      throw AuthenticationException(
        source: 'firebase-config',
        code: 'project-mismatch',
        message: 'Firebase project mismatch: expected $googleFirebaseProjectId '
            'but the app is using ${options.projectId}.',
      );
    }

    if (options.appId != googleFirebaseAndroidAppId) {
      throw AuthenticationException(
        source: 'firebase-config',
        code: 'android-app-mismatch',
        message:
            'Firebase Android app mismatch: expected $googleFirebaseAndroidAppId '
            'but the app is using ${options.appId}.',
      );
    }
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    await _ensureGoogleSignInInitialized();
    await _googleSignIn.signOut();
  }

  void _debugLog(Object error, StackTrace stack) {
    // Authentication failure monitoring. The diagnostics port redacts before
    // anything leaves: an auth error can carry an email address.
    _diagnostics.recordFailure(
      DiagnosticArea.auth,
      'sign_in_failed',
      error,
      stack: stack,
    );
  }

  AppUser? _mapUser(User? user) {
    if (user == null) return null;

    return AppUser(
      id: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
      photoUrl: user.photoURL,
    );
  }
}

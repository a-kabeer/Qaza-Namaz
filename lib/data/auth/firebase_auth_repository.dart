import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/diagnostics/diagnostics.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
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
  const AuthenticationCancelledException({
    this.userInitiated = true,
    String? description,
  }) : super(
          source: 'google-sign-in',
          code: 'canceled',
          message: description != null && description.trim().isNotEmpty
              ? description
              : 'Google Sign-In was cancelled by the user.',
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

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    DiagnosticsService diagnostics = const NoopDiagnostics(),
  })  : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
        _diagnostics = diagnostics;

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final DiagnosticsService _diagnostics;

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
        .initialize(serverClientId: googleServerClientId)
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
  Future<AppUser> signInWithGoogle() async {
    try {
      _validateFirebaseConfiguration();

      final account = await GoogleAuthFlow(
        beginGoogleSignIn: () async {
          await _ensureGoogleSignInInitialized();

          requireAuthenticateSupport(_googleSignIn.supportsAuthenticate());

          final googleUser = await _googleSignIn.authenticate();
          final authentication = googleUser.authentication;
          return GoogleIdentityTokens(idToken: authentication.idToken);
        },
        signInToFirebase: (tokens) async {
          final idToken = requireIdToken(tokens.idToken);

          final credential = GoogleAuthProvider.credential(idToken: idToken);
          final result = await _auth.signInWithCredential(credential);
          return requireFirebaseUser(_mapUser(result.user));
        },
      ).signIn();

      return account;
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
        final description = error.description;
        return AuthenticationCancelledException(
          userInitiated:
              description == null || description.trim().isEmpty,
          description: description,
        );
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

  static String _googleFailureMessage(GoogleSignInException error) {
    final description = error.description?.trim();
    final details = error.details;

    if (description != null && description.isNotEmpty) {
      if (details == null) return description;
      return '$description (details: ${details.toString()})';
    }
    if (details != null) return details.toString();
    return error.toString();
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

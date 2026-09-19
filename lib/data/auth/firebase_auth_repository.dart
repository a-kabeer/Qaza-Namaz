import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
  const AuthenticationCancelledException()
      : super(
          source: 'google',
          code: 'cancelled',
          message: 'Google Sign-In was cancelled by the user.',
        );

  @override
  String toString() => message;
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn =
            googleSignIn ?? GoogleSignIn(serverClientId: googleServerClientId);

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

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
          final googleUser = await _googleSignIn.signIn();
          if (googleUser == null) return null;
          final authentication = await googleUser.authentication;
          return GoogleIdentityTokens(idToken: authentication.idToken);
        },
        signInToFirebase: (tokens) async {
          final idToken = tokens.idToken;
          if (idToken == null || idToken.isEmpty) {
            throw StateError(
              'Google Sign-In completed without an ID token. '
              'Check the Android OAuth client, SHA-1/SHA-256 fingerprints, '
              'package ID, and Firebase Google provider configuration.',
            );
          }

          final credential = GoogleAuthProvider.credential(idToken: idToken);
          final result = await _auth.signInWithCredential(credential);
          final user = result.user;
          if (user == null) {
            throw StateError(
              'Firebase Authentication returned no user after Google '
              'credential sign-in.',
            );
          }
          return _mapUser(user)!;
        },
      ).signIn();

      return account;
    } on GoogleAuthFlowCancelledException {
      throw const AuthenticationCancelledException();
    } on AuthenticationException {
      rethrow;
    } on FirebaseAuthException catch (error, stack) {
      _debugLog(error, stack);
      throw AuthenticationException(
        source: 'firebase-auth',
        code: error.code,
        message: error.message?.trim().isNotEmpty == true
            ? error.message!
            : error.toString(),
        cause: error,
        stackTrace: stack,
      );
    } on PlatformException catch (error, stack) {
      _debugLog(error, stack);
      throw AuthenticationException(
        source: 'platform',
        code: error.code,
        message: error.message?.trim().isNotEmpty == true
            ? error.message!
            : error.toString(),
        cause: error,
        stackTrace: stack,
      );
    } catch (error, stack) {
      _debugLog(error, stack);
      throw AuthenticationException(
        source: 'google',
        code: error.runtimeType.toString(),
        message: error.toString(),
        cause: error,
        stackTrace: stack,
      );
    }
  }

  void _validateFirebaseConfiguration() {
    final options = Firebase.app().options;

    if (options.projectId != googleFirebaseProjectId) {
      throw AuthenticationException(
        source: 'firebase-config',
        code: 'project-mismatch',
        message:
            'Firebase project mismatch: expected ${googleFirebaseProjectId} '
            'but the app is using ${options.projectId}.',
      );
    }

    if (options.appId != googleFirebaseAndroidAppId) {
      throw AuthenticationException(
        source: 'firebase-config',
        code: 'android-app-mismatch',
        message:
            'Firebase Android app mismatch: expected ${googleFirebaseAndroidAppId} '
            'but the app is using ${options.appId}.',
      );
    }
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }

  void _debugLog(Object error, StackTrace stack) {
    if (!kDebugMode) return;
    debugPrint('[auth] ${error.runtimeType}: $error');
    debugPrintStack(stackTrace: stack);
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

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/diagnostics/diagnostics.dart';

class FirebaseConfiguration {
  static const projectId = 'qaza-nmz';
  static const projectNumber = '895430705174';
  static const androidAppId = '1:895430705174:android:83eb9e77acad787f3c7537';
  static const androidPackage = 'com.qaza_namaz.com';
  static const androidSha1 =
      '3a:b6:c8:b5:08:a6:85:79:25:4d:31:98:37:16:f5:d2:ba:bd:41:8d';
  static const androidSha256 =
      'f6:88:91:74:14:7f:0d:ec:58:86:be:2b:97:05:f0:40:5f:65:b3:c1:05:fe:51:f7:76:c2:91:9f:aa:93:b3:4d';
  static const webClientId =
      '895430705174-alhhbpbn958gt8t7e3d0mr3bqogo19sv.apps.googleusercontent.com';
}

class FirebaseServices {
  FirebaseServices({
    DiagnosticsService diagnostics = const NoopDiagnostics(),
  }) : _diagnostics = diagnostics;

  final DiagnosticsService _diagnostics;
  bool _initialized = false;
  Future<void>? _initializing;

  static const Duration initializationTimeout = Duration(seconds: 8);

  bool get initialized => _initialized;

  Future<bool> initialize() async {
    if (_initialized) return true;

    final running = _initializing;
    if (running != null) {
      return running
          .then((_) => _initialized)
          .timeout(initializationTimeout, onTimeout: () => false);
    }

    final future = _initializeInternal();
    _initializing = future;

    unawaited(
      future.then<void>(
        (_) {
          if (identical(_initializing, future)) {
            _initializing = null;
          }
        },
        onError: (Object _, StackTrace __) {
          if (identical(_initializing, future)) {
            _initializing = null;
          }
        },
      ),
    );

    try {
      await future.timeout(initializationTimeout);
      return _initialized;
    } on TimeoutException {
      // Do not cancel the underlying initialization. Keep the shared future
      // owned by the service so later callers cannot start a second Firebase /
      // Google initialization while this attempt is still completing.
      return false;
    }
  }

  Future<void> _initializeInternal() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      await GoogleSignIn.instance.initialize(
        serverClientId: FirebaseConfiguration.webClientId,
      );

      await FirebaseAppCheck.instance.activate(
        providerAndroid: kReleaseMode
            ? const AndroidPlayIntegrityProvider()
            : const AndroidDebugProvider(),
      );

      _initialized = true;
    } catch (error, stack) {
      _diagnostics.recordFailure(
        DiagnosticArea.startup,
        'firebase_initialize_failed',
        error,
        stack: stack,
      );
    }
  }

  FirebaseAuth get auth => FirebaseAuth.instance;

  FirebaseFirestore get firestore => FirebaseFirestore.instance;
}

class GoogleFirebaseIdentity {
  const GoogleFirebaseIdentity({required this.uid, this.email});

  final String uid;
  final String? email;
}

class GoogleFirebaseAuthService {
  GoogleFirebaseAuthService(this.services);

  final FirebaseServices services;
  static bool _authenticationInFlight = false;

  User? get currentUser =>
      services.initialized ? services.auth.currentUser : null;

  Future<User?> signIn() async {
    _beginAuthentication();
    final operation = _signInInternal();
    _releaseAuthenticationWhenComplete(operation);
    return operation;
  }

  Future<GoogleFirebaseIdentity> signInIdentity() async {
    final user = await signIn();
    if (user == null) {
      throw StateError('Google authentication returned no user.');
    }
    return GoogleFirebaseIdentity(
      uid: user.uid,
      email: user.email,
    );
  }

  Future<User?> _signInInternal() async {
    if (!await services.initialize()) {
      throw StateError('Firebase is not available.');
    }

    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw StateError('Google Sign-In authentication is unavailable.');
    }

    // Never impose a Dart timeout on the interactive Credential Manager
    // request. A timeout would not cancel the native request and could allow
    // a retry to open a second authentication UI while the first remains alive.
    final googleUser = await GoogleSignIn.instance.authenticate();
    final idToken = googleUser.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Google Sign-In did not return an ID token.');
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final result = await services.auth
        .signInWithCredential(credential)
        .timeout(const Duration(seconds: 15));
    return result.user;
  }

  /// Restores a cached Google/Firebase identity without invoking the
  /// interactive account picker. This is startup-only authentication; explicit
  /// user initiated sign-in continues to use [signIn].
  Future<GoogleFirebaseIdentity?> attemptLightweightAuthentication({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (_authenticationInFlight) return null;

    _beginAuthentication();
    final operation = _attemptLightweightAuthenticationInternal(timeout);
    _releaseAuthenticationWhenComplete(operation);
    return operation;
  }

  Future<GoogleFirebaseIdentity?> _attemptLightweightAuthenticationInternal(
    Duration timeout,
  ) async {
    if (!await services.initialize().timeout(timeout, onTimeout: () => false)) {
      return null;
    }

    final firebaseUser = services.auth.currentUser;
    if (firebaseUser != null) {
      return GoogleFirebaseIdentity(
        uid: firebaseUser.uid,
        email: firebaseUser.email,
      );
    }

    try {
      final lightweightFuture =
          GoogleSignIn.instance.attemptLightweightAuthentication();
      if (lightweightFuture == null) return null;
      final googleUser = await lightweightFuture.timeout(timeout);
      if (googleUser == null) return null;

      final idToken = googleUser.authentication.idToken;
      if (idToken == null || idToken.isEmpty) return null;

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final result =
          await services.auth.signInWithCredential(credential).timeout(timeout);
      final user = result.user;
      if (user == null) return null;
      return GoogleFirebaseIdentity(uid: user.uid, email: user.email);
    } catch (_) {
      // Lightweight restoration is best-effort. Startup must remain usable
      // with the local account when Google/Firebase is unavailable.
      final user = services.auth.currentUser;
      return user == null
          ? null
          : GoogleFirebaseIdentity(uid: user.uid, email: user.email);
    }
  }

  void _beginAuthentication() {
    if (_authenticationInFlight) {
      throw StateError('Google authentication is already in progress.');
    }
    _authenticationInFlight = true;
  }

  void _releaseAuthenticationWhenComplete(Future<Object?> operation) {
    unawaited(
      operation.then<void>(
        (_) => _authenticationInFlight = false,
        onError: (Object _, StackTrace __) => _authenticationInFlight = false,
      ),
    );
  }

  Future<void> signOut() async {
    if (!services.initialized) return;
    try {
      await GoogleSignIn.instance.signOut();
    } finally {
      await services.auth.signOut();
    }
  }

  Future<void> disconnect() async {
    if (!services.initialized) return;
    try {
      await GoogleSignIn.instance.disconnect();
    } finally {
      await services.auth.signOut();
    }
  }
}

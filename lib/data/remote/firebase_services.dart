import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/diagnostics/diagnostics.dart';
import 'backup_failure.dart';

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

enum FirebaseInitializationFailure {
  firebaseCoreFailure,
  googleSignInFailure,
  appCheckFailure,
  timeout,
}

class FirebaseInitializationResult {
  const FirebaseInitializationResult({
    required this.firebaseCoreInitialized,
    required this.googleSignInInitialized,
    required this.appCheckInitialized,
    this.failure,
  });

  final bool firebaseCoreInitialized;
  final bool googleSignInInitialized;
  final bool appCheckInitialized;
  final FirebaseInitializationFailure? failure;

  bool get authenticationReady =>
      firebaseCoreInitialized && googleSignInInitialized;

  bool get firestoreReady =>
      firebaseCoreInitialized && appCheckInitialized;
}

class FirebaseServices {
  FirebaseServices({
    DiagnosticsService diagnostics = const NoopDiagnostics(),
  }) : _diagnostics = diagnostics;

  final DiagnosticsService _diagnostics;
  bool _firebaseCoreInitialized = false;
  bool _googleSignInInitialized = false;
  bool _appCheckInitialized = false;
  bool _appCheckTokenAvailable = false;
  bool _appCheckTokenListenerAttached = false;
  Future<FirebaseInitializationResult>? _initializing;
  Future<bool>? _firebaseCoreInitializing;
  Future<bool>? _googleSignInInitializing;
  FirebaseInitializationResult? _lastInitializationResult;

  static const Duration initializationTimeout = Duration(seconds: 8);

  bool get initialized => _firebaseCoreInitialized;

  bool get firebaseCoreInitialized => _firebaseCoreInitialized;
  bool get googleSignInInitialized => _googleSignInInitialized;
  bool get appCheckInitialized => _appCheckInitialized;
  bool get appCheckTokenAvailable => _appCheckTokenAvailable;

  FirebaseInitializationResult get initializationResult =>
      _lastInitializationResult ??
      FirebaseInitializationResult(
        firebaseCoreInitialized: _firebaseCoreInitialized,
        googleSignInInitialized: _googleSignInInitialized,
        appCheckInitialized: _appCheckInitialized,
      );

  Future<bool> initialize() async {
    final result = await initializeDetailed();
    return result.firebaseCoreInitialized;
  }

  Future<FirebaseInitializationResult> initializeDetailed() async {
    final running = _initializing;
    if (running != null) {
      try {
        return await running.timeout(initializationTimeout);
      } on TimeoutException {
        return FirebaseInitializationResult(
          firebaseCoreInitialized: _firebaseCoreInitialized,
          googleSignInInitialized: _googleSignInInitialized,
          appCheckInitialized: _appCheckInitialized,
          failure: FirebaseInitializationFailure.timeout,
        );
      }
    }

    if (_firebaseCoreInitialized &&
        _googleSignInInitialized &&
        _appCheckInitialized) {
      return _lastInitializationResult ??=
          FirebaseInitializationResult(
        firebaseCoreInitialized: true,
        googleSignInInitialized: true,
        appCheckInitialized: true,
      );
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
      final result = await future.timeout(initializationTimeout);
      _lastInitializationResult = result;
      return result;
    } on TimeoutException {
      return FirebaseInitializationResult(
        firebaseCoreInitialized: _firebaseCoreInitialized,
        googleSignInInitialized: _googleSignInInitialized,
        appCheckInitialized: _appCheckInitialized,
        failure: FirebaseInitializationFailure.timeout,
      );
    }
  }

  /// Initializes Firebase Core independently from the native Google picker.
  Future<bool> initializeFirebaseCore() async {
    if (_firebaseCoreInitialized) return true;
    final running = _firebaseCoreInitializing;
    if (running != null) {
      try {
        return await running.timeout(initializationTimeout);
      } on TimeoutException {
        return _firebaseCoreInitialized;
      }
    }
    final future = _initializeFirebaseCoreInternal();
    _firebaseCoreInitializing = future;
    unawaited(future.then<void>((_) {
      if (identical(_firebaseCoreInitializing, future)) {
        _firebaseCoreInitializing = null;
      }
    }, onError: (Object _, StackTrace __) {
      if (identical(_firebaseCoreInitializing, future)) {
        _firebaseCoreInitializing = null;
      }
    }));
    try {
      return await future.timeout(initializationTimeout);
    } on TimeoutException {
      return _firebaseCoreInitialized;
    }
  }

  Future<bool> _initializeFirebaseCoreInternal() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _firebaseCoreInitialized = true;
      return true;
    } catch (error, stack) {
      _diagnostics.recordFailure(
        DiagnosticArea.startup,
        'firebase_core_initialize_failed',
        error,
        stack: stack,
      );
      return false;
    }
  }

  /// Initializes Google Sign-In independently so the native account picker
  /// can open without waiting for Firebase Core/App Check/Firestore setup.
  Future<bool> initializeGoogleSignIn() async {
    if (_googleSignInInitialized) return true;
    final running = _googleSignInInitializing;
    if (running != null) {
      try {
        return await running.timeout(initializationTimeout);
      } on TimeoutException {
        return _googleSignInInitialized;
      }
    }
    final future = _initializeGoogleSignInInternal();
    _googleSignInInitializing = future;
    unawaited(future.then<void>((_) {
      if (identical(_googleSignInInitializing, future)) {
        _googleSignInInitializing = null;
      }
    }, onError: (Object _, StackTrace __) {
      if (identical(_googleSignInInitializing, future)) {
        _googleSignInInitializing = null;
      }
    }));
    try {
      return await future.timeout(initializationTimeout);
    } on TimeoutException {
      return _googleSignInInitialized;
    }
  }

  Future<bool> _initializeGoogleSignInInternal() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      await GoogleSignIn.instance.initialize(
        serverClientId: FirebaseConfiguration.webClientId,
      );
      _googleSignInInitialized = true;
      return true;
    } catch (error, stack) {
      _diagnostics.recordFailure(
        DiagnosticArea.startup,
        'google_sign_in_initialize_failed',
        error,
        stack: stack,
      );
      return false;
    }
  }

  /// Startup warm-up initializes Firebase Core and Google Sign-In concurrently.
  Future<bool> initializeAuthentication() async {
    final results = await Future.wait<bool>([
      initializeFirebaseCore(),
      initializeGoogleSignIn(),
    ]);
    return results.every((ready) => ready);
  }

  Future<FirebaseInitializationResult> _initializeInternal() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      const result = FirebaseInitializationResult(
        firebaseCoreInitialized: false,
        googleSignInInitialized: false,
        appCheckInitialized: false,
        failure: FirebaseInitializationFailure.firebaseCoreFailure,
      );
      _diagnostics.recordEvent(
        DiagnosticArea.startup,
        'firebase_android_initialization_skipped',
      );
      return result;
    }

    final authReady = await initializeAuthentication();
    FirebaseInitializationFailure? failure = authReady
        ? null
        : !_firebaseCoreInitialized
            ? FirebaseInitializationFailure.firebaseCoreFailure
            : FirebaseInitializationFailure.googleSignInFailure;

    if (_firebaseCoreInitialized && !_appCheckInitialized) {
      try {
        await FirebaseAppCheck.instance.activate(
          providerAndroid: kReleaseMode
              ? const AndroidPlayIntegrityProvider()
              : const AndroidDebugProvider(),
        );
        _appCheckInitialized = true;
        if (!_appCheckTokenListenerAttached) {
          _appCheckTokenListenerAttached = true;
          FirebaseAppCheck.instance.onTokenChange.listen(
            (token) {
              _appCheckTokenAvailable = token?.isNotEmpty == true;
              _diagnostics.recordEvent(
                DiagnosticArea.sync,
                _appCheckTokenAvailable
                    ? 'app_check_token_available'
                    : 'app_check_token_unavailable',
              );
            },
            onError: (Object error, StackTrace stack) {
              _appCheckTokenAvailable = false;
              _diagnostics.recordFailure(
                DiagnosticArea.sync,
                'app_check_token_listener_failed',
                error,
                stack: stack,
              );
            },
          );
        }
        _diagnostics.recordEvent(
          DiagnosticArea.startup,
          kReleaseMode
              ? 'app_check_play_integrity_provider_activated'
              : 'app_check_debug_provider_activated',
        );
      } catch (error, stack) {
        failure ??= FirebaseInitializationFailure.appCheckFailure;
        _diagnostics.recordFailure(
          DiagnosticArea.startup,
          'app_check_initialize_failed',
          error,
          stack: stack,
        );
      }
    }

    final result = FirebaseInitializationResult(
      firebaseCoreInitialized: _firebaseCoreInitialized,
      googleSignInInitialized: _googleSignInInitialized,
      appCheckInitialized: _appCheckInitialized,
      failure: failure,
    );
    _lastInitializationResult = result;
    return result;
  }

  Future<void> ensureFirestoreReady() async {
    final result = await initializeDetailed();
    if (!result.firebaseCoreInitialized) {
      throw BackupFailure(
        category: BackupFailureCategory.firebaseInitializationFailed,
        message: 'Firebase Core initialization failed.',
        cause: result.failure,
      );
    }
    if (!result.appCheckInitialized) {
      throw BackupFailure(
        category: BackupFailureCategory.appCheckInitializationFailed,
        message: 'Firebase App Check initialization failed.',
        cause: result.failure,
      );
    }

    // Firebase SDKs automatically attach and refresh App Check tokens for
    // protected requests. Do not force-refresh a token before every cloud
    // operation: that adds attestation latency/quota pressure and can race a
    // normal token acquisition.
    if (!_appCheckTokenAvailable) {
      _diagnostics.recordEvent(
        DiagnosticArea.sync,
        'app_check_token_not_yet_available',
      );
    }
  }

  Future<void> ensureAppCheckTokenAvailable({
    bool forceRefresh = false,
  }) async {
    await ensureFirestoreReady();
    try {
      final token = await FirebaseAppCheck.instance.getToken(forceRefresh);
      if (token == null || token.isEmpty) {
        _appCheckTokenAvailable = false;
        throw const BackupFailure(
          category: BackupFailureCategory.appCheckTokenUnavailable,
          message: 'Firebase App Check token is unavailable.',
        );
      }
      _appCheckTokenAvailable = true;
      _diagnostics.recordEvent(
        DiagnosticArea.sync,
        'app_check_token_available',
      );
    } catch (error, stack) {
      _appCheckTokenAvailable = false;
      final failure = error is BackupFailure
          ? error
          : BackupFailure(
              category: BackupFailureCategory.appCheckTokenUnavailable,
              message: 'Firebase App Check token could not be obtained.',
              cause: error,
              stackTrace: stack,
            );
      _diagnostics.recordFailure(
        DiagnosticArea.sync,
        'app_check_token_request_failed',
        error,
        stack: stack,
      );
      throw failure;
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
    if (!await services.initializeGoogleSignIn()) {
      throw StateError('Google Sign-In is not available.');
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

    if (!await services.initializeFirebaseCore()) {
      throw StateError('Firebase Core is not available.');
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
    final ready = await Future.wait<bool>([
      services.initializeFirebaseCore().timeout(timeout, onTimeout: () => false),
      services.initializeGoogleSignIn().timeout(timeout, onTimeout: () => false),
    ]);
    if (!ready.every((value) => value)) {
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

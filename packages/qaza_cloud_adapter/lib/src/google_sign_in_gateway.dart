import 'dart:async';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import 'cloud_models.dart';

class GoogleSignInGateway {
  GoogleSignInGateway({
    String? clientId,
    String? serverClientId,
    GoogleSignIn? googleSignIn,
  }) : _clientId = clientId,
       _serverClientId = serverClientId,
       _signIn = googleSignIn ?? GoogleSignIn.instance;

  final String? _clientId;
  final String? _serverClientId;
  final GoogleSignIn _signIn;

  bool _initialized = false;
  GoogleSignInAccount? _resolvedAccount;
  Future<void> _tail = Future<void>.value();

  Future<void> initialize() => _serialized<void>(() async {
    await _initializeUnlocked();
  });

  Future<GoogleSignInAccount> authenticate() =>
      _serialized(() => _authenticateUnlocked());

  Future<void> signOut() => _serialized(() async {
    await _initializeUnlocked();
    await _signIn.signOut();
    _resolvedAccount = null;
  });

  /// Reads only an account that was resolved by an explicit sign-in in this
  /// gateway instance. There is intentionally no plugin "current user" getter
  /// in google_sign_in 7.x, and we do not attempt lightweight auth here because
  /// passive restoration has been observed to open UI on Android.
  Future<GoogleSignInAccount?> currentAccount() => _serialized(() async {
    await _initializeUnlocked();
    return _resolvedAccount;
  });

  /// Kept as a compatibility alias; this is now a read-only lookup.
  Future<GoogleSignInAccount?> restoreLightweightAuthentication() =>
      currentAccount();

  Future<http.Client?> authorizeDrive({required bool allowInteractive}) =>
      _serialized(() async {
        await _initializeUnlocked();

        // Never invoke a lightweight-authentication attempt here. The Android
        // implementation can present UI in edge cases, and this method is also
        // used by WorkManager. Only an explicit interactive operation may call
        // authenticate().
        var user = _resolvedAccount;
        if (user == null) {
          if (!allowInteractive) {
            throw const CloudAuthorizationUnavailable();
          }
          user = await _authenticateUnlocked();
        }

        final authorization = await user.authorizationClient
            .authorizationForScopes(const <String>[cloudDriveScope]);

        final resolvedAuthorization =
            authorization ??
            (allowInteractive
                ? await user.authorizationClient.authorizeScopes(const <String>[
                    cloudDriveScope,
                  ])
                : null);

        if (resolvedAuthorization == null) {
          throw const CloudAuthorizationUnavailable();
        }

        return resolvedAuthorization.authClient(
          scopes: const <String>[cloudDriveScope],
        );
      });

  Future<void> _initializeUnlocked() async {
    if (_initialized) return;
    await _signIn.initialize(
      clientId: _clientId,
      serverClientId: _serverClientId,
    );
    _initialized = true;
  }

  Future<GoogleSignInAccount> _authenticateUnlocked() async {
    await _initializeUnlocked();
    if (!_signIn.supportsAuthenticate()) {
      throw const CloudAuthenticationRequired(
        'This platform does not support interactive Google authentication '
        'through the current Google Sign-In API.',
      );
    }
    final account = await _signIn.authenticate();
    _resolvedAccount = account;
    return account;
  }

  Future<T> _serialized<T>(Future<T> Function() action) async {
    final previous = _tail;
    final done = Completer<void>();
    _tail = done.future;
    await previous;
    try {
      return await action();
    } finally {
      done.complete();
    }
  }
}

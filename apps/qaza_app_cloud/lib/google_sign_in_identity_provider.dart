import 'dart:async';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:qaza_namaz/domain/services/google_identity_contracts.dart';

/// Google authentication for the cloud-enabled app target.
///
/// This class deliberately knows nothing about Google Drive, OAuth Drive
/// scopes, HTTP clients, backups, or remote database state.
class GoogleSignInIdentityProvider implements GoogleIdentityProvider {
  GoogleSignInIdentityProvider({this.serverClientId})
      : _signIn = GoogleSignIn.instance;

  final String? serverClientId;
  final GoogleSignIn _signIn;

  bool _initialized = false;
  GoogleSignInAccount? _currentAccount;
  Future<void>? _initializing;
  Future<void> _tail = Future<void>.value();

  @override
  bool get isSupported => true;

  Future<void> _initialize() async {
    if (_initialized) return;
    final running = _initializing;
    if (running != null) {
      await running;
      return;
    }
    final future = _signIn.initialize(
      serverClientId: (serverClientId?.trim().isEmpty ?? true)
          ? null
          : serverClientId!.trim(),
    );
    _initializing = future;
    try {
      await future;
      _initialized = true;
    } finally {
      if (identical(_initializing, future)) _initializing = null;
    }
  }

  @override
  Future<GoogleIdentitySnapshot> restore() => _serialized(() async {
        await _initialize();
        // Do not launch lightweight auth during startup: on Android it may
        // surface account UI. The local session manager already restores the
        // active workspace. Account identity is refreshed only by an explicit
        // sign-in gesture in this build.
        final account = _currentAccount;
        return account == null
            ? const GoogleIdentitySnapshot.signedOut()
            : _snapshot(account);
      });

  @override
  Future<GoogleIdentitySnapshot> signIn() => _serialized(() async {
        await _initialize();
        try {
          if (!_signIn.supportsAuthenticate()) {
            return const GoogleIdentitySnapshot.failed(
              'Google Sign-In is not supported on this platform.',
            );
          }
          final account = await _signIn.authenticate();
          _currentAccount = account;
          return _snapshot(account);
        } catch (error) {
          final message = error.toString();
          if (message.toLowerCase().contains('cancel')) {
            return const GoogleIdentitySnapshot.cancelled();
          }
          return GoogleIdentitySnapshot.failed(message);
        }
      });

  @override
  Future<void> signOut() => _serialized(() async {
        await _initialize();
        await _signIn.signOut();
        _currentAccount = null;
      });

  GoogleIdentitySnapshot _snapshot(GoogleSignInAccount account) {
    final id = account.id.trim();
    if (id.isEmpty) {
      return const GoogleIdentitySnapshot.failed(
        'Google returned an empty account identifier.',
      );
    }
    return GoogleIdentitySnapshot.signedIn(
      accountId: id,
      displayName: account.displayName,
      email: account.email,
      photoUrl: account.photoUrl,
    );
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

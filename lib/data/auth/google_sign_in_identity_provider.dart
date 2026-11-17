import 'dart:async';

import 'package:google_sign_in/google_sign_in.dart';
import '../../domain/services/google_identity_contracts.dart';

/// Native Google authentication provider.
///
/// Prompts the native Android/iOS account picker directly without opening a web browser,
/// obtaining the Google ID token for local workspace scoping and Supabase auth.
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
        final account = _currentAccount;
        return account == null
            ? const GoogleIdentitySnapshot.signedOut()
            : _snapshot(account);
      });

  @override
  Future<GoogleIdentitySnapshot> signIn() => _serialized(() async {
        final result = await _signInInternal();
        return result.snapshot;
      });

  /// Performs native Google Sign-In and returns both identity snapshot and ID token.
  Future<({GoogleIdentitySnapshot snapshot, String? idToken})>
      signInWithTokens() => _serialized(() => _signInInternal());

  Future<({GoogleIdentitySnapshot snapshot, String? idToken})>
      _signInInternal() async {
    await _initialize();
    try {
      if (!_signIn.supportsAuthenticate()) {
        return (
          snapshot: const GoogleIdentitySnapshot.failed(
            'Google Sign-In is not supported on this platform.',
          ),
          idToken: null,
        );
      }
      final account = await _signIn.authenticate();
      _currentAccount = account;
      final auth = account.authentication;
      return (
        snapshot: _snapshot(account),
        idToken: auth.idToken,
      );
    } catch (error) {
      final message = error.toString();
      if (message.toLowerCase().contains('cancel')) {
        return (
          snapshot: const GoogleIdentitySnapshot.cancelled(),
          idToken: null,
        );
      }
      return (
        snapshot: GoogleIdentitySnapshot.failed(message),
        idToken: null,
      );
    }
  }

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

import 'dart:async';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'cloud_models.dart';

const MethodChannel _backgroundAuthorizationChannel = MethodChannel(
  'qaza_cloud_adapter/google_drive_authorization',
);
const String _cachedAccountEmailKey =
    'qaza_cloud_adapter.cached_account_email_v1';
const String _cachedAccountIdKey = 'qaza_cloud_adapter.cached_account_id_v1';

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
  String? _pinnedAccountId;
  Future<void> _tail = Future<void>.value();

  Future<void> initialize() => _serialized<void>(() async {
    await _initializeUnlocked();
  });

  Future<GoogleSignInAccount> authenticate() =>
      _serialized(() => _authenticateUnlocked());

  /// Signs out of this app without revoking the user's Google authorization.
  /// Callers must stop scheduled work before invoking this method.
  Future<void> signOut() => _serialized(() async {
    await _initializeUnlocked();
    await _signIn.signOut();
    _resolvedAccount = null;
  });

  /// Stable Google account identifier associated with the current runtime or
  /// the previously verified account binding. Cached profile data alone is
  /// not an authorization grant; Drive authorization is still checked before
  /// any sync operation uses account-scoped state.
  Future<String?> accountIdForAuthorization() => _serialized(() async {
    await _initializeUnlocked();
    final account = _resolvedAccount;
    if (account != null) return account.id.trim().isEmpty ? null : account.id;
    return _storedAccountId();
  });

  /// Pins all subsequent Drive authorizations during one sync to its verified
  /// account. This prevents a concurrent account switch from redirecting later
  /// Drive requests to a different user's backup.
  void pinAccountForOperation(String accountId) {
    final normalized = accountId.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(accountId, 'accountId', 'Must not be empty.');
    }
    if (_pinnedAccountId != null && _pinnedAccountId != normalized) {
      throw const CloudAuthorizationUnavailable(
        'Another Google account operation is already in progress.',
      );
    }
    final runtimeId = _resolvedAccount?.id;
    if (runtimeId != null && runtimeId != normalized) {
      throw const CloudAuthorizationUnavailable(
        'The authenticated Google account changed before sync could start.',
      );
    }
    _pinnedAccountId = normalized;
  }

  void releaseAccountOperation(String accountId) {
    if (_pinnedAccountId == accountId) _pinnedAccountId = null;
  }

  Future<String?> _storedAccountId() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_cachedAccountIdKey)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  /// Returns an account resolved by this runtime's explicit sign-in flow.
  ///
  /// Google Sign-In 7.x has no synchronous current-user getter. Cached profile
  /// metadata is deliberately not used to manufacture an authenticated account.
  Future<GoogleSignInAccount?> currentAccount() => _serialized(() async {
    await _initializeUnlocked();
    return _resolvedAccount;
  });

  /// Compatibility alias retained for existing call sites. Passive restore
  /// must not call attemptLightweightAuthentication(), which can surface UI on
  /// Android. A fresh runtime uses the native silent Drive path instead.
  Future<GoogleSignInAccount?> restoreLightweightAuthentication() =>
      currentAccount();

  Future<http.Client?> authorizeDrive({required bool allowInteractive}) =>
      _serialized(() async {
        await _initializeUnlocked();

        final pinnedAccountId = _pinnedAccountId;
        if (pinnedAccountId != null) {
          final runtimeId = _resolvedAccount?.id;
          final persistedId = runtimeId == null
              ? await _storedAccountId()
              : runtimeId;
          if (persistedId != pinnedAccountId) {
            throw const CloudAuthorizationUnavailable(
              'The Google account changed during sync. No further Drive '
              'requests will be made until the account is reverified.',
            );
          }
        }

        // WorkManager runs in a separate Flutter engine and cannot depend on
        // this gateway's in-memory GoogleSignInAccount. A foreground caller
        // can also be a fresh runtime (for example, Backup Now after relaunch).
        // Try the native authorization path first whenever this runtime has no
        // account object, or when interaction is forbidden. A valid existing
        // grant then works without another sign-in sheet.
        if (defaultTargetPlatform == TargetPlatform.android &&
            _resolvedAccount == null) {
          try {
            return await _authorizeDriveSilentlyOnAndroid();
          } on CloudAccountIdentityMismatch {
            // An account mismatch is not a missing permission. Never let this
            // fall through to an interactive account picker.
            rethrow;
          } on CloudAuthorizationUnavailable {
            // A foreground user action may now complete missing consent.
            // Background callers must never fall through to UI.
            if (!allowInteractive) rethrow;
          }
        }

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

  Future<http.Client> _authorizeDriveSilentlyOnAndroid() async {
    final preferences = await SharedPreferences.getInstance();
    final expectedAccountId = preferences
        .getString(_cachedAccountIdKey)
        ?.trim();
    final expectedEmail = preferences.getString(_cachedAccountEmailKey)?.trim();
    if (expectedAccountId == null ||
        expectedAccountId.isEmpty ||
        expectedEmail == null ||
        expectedEmail.isEmpty) {
      throw const CloudAuthorizationUnavailable(
        'Google Drive authorization cannot be restored because the previously '
        'connected account identity could not be verified. Open Settings → '
        'Account and reconnect Google.',
      );
    }
    final runtimeAccount = _resolvedAccount;
    if (_pinnedAccountId != null && _pinnedAccountId != expectedAccountId) {
      throw const CloudAuthorizationUnavailable(
        'The selected Google account changed during sync. Reconnect before retrying.',
      );
    }
    if (runtimeAccount != null && runtimeAccount.id != expectedAccountId) {
      throw const CloudAuthorizationUnavailable(
        'The authenticated Google account does not match the saved backup '
        'account. Reconnect the intended account before syncing.',
      );
    }

    final response = await _backgroundAuthorizationChannel
        .invokeMapMethod<String, Object?>(
          'authorizeDriveSilently',
          <String, Object?>{
            'accountId': expectedAccountId,
            'accountEmail': expectedEmail,
          },
        );
    final status = response?['status'];

    if (status == 'interactionRequired') {
      throw const CloudAuthorizationUnavailable(
        'Google Drive authorization needs attention. Open Settings → Account '
        'and reconnect Google.',
      );
    }
    if (status == 'accountMismatch') {
      final message = response?['message'];
      throw CloudAccountIdentityMismatch(
        message is String && message.trim().isNotEmpty
            ? message
            : 'Google Drive authorized a different or unverifiable account.',
      );
    }

    if (status != 'authorized') {
      final message = response?['message'];
      throw CloudAdapterException(
        message is String && message.trim().isNotEmpty
            ? message
            : 'Google Drive authorization is temporarily unavailable.',
      );
    }

    final accessToken = response?['accessToken'];
    final rawScopes = response?['grantedScopes'];
    final grantedScopes = rawScopes is List
        ? rawScopes.whereType<String>().toSet()
        : <String>{};

    final authorizedAccountId = response?['accountId'];
    final authorizedEmail = response?['accountEmail'];
    final identitySource = response?['identitySource'];
    final idMatches =
        authorizedAccountId is String &&
        authorizedAccountId.trim().isNotEmpty &&
        authorizedAccountId == expectedAccountId;
    final emailMatches =
        authorizedEmail is String &&
        authorizedEmail.trim().isNotEmpty &&
        authorizedEmail.trim().toLowerCase() == expectedEmail.toLowerCase();

    // AuthorizationClient is pinned to the previously verified Android
    // Account(email). Its legacy account projection can omit the stable ID.
    // In that case native code returns the previously bound ID only as a
    // namespace binding and explicitly labels the matching target-email proof.
    final identityVerified = switch (identitySource) {
      'googleId' => idMatches && emailMatches,
      'targetAccountEmail' => idMatches && emailMatches,
      // The native Android request pins AuthorizationClient to the previously
      // verified Account(email). A successful token response may not contain
      // profile identity fields, so accept the native pinned-account provenance
      // only when its echoed binding still matches both saved identity values.
      'pinnedAndroidAccount' => idMatches && emailMatches,
      _ => false,
    };
    if (!identityVerified) {
      throw const CloudAccountIdentityMismatch(
        'Google Drive authorization did not confirm the previously connected Google account.',
      );
    }
    if (accessToken is! String ||
        accessToken.isEmpty ||
        !grantedScopes.contains(cloudDriveScope)) {
      throw const CloudAuthorizationUnavailable(
        'Google Drive authorization is not available for the backup scope.',
      );
    }

    // The OAuth token remains in memory only. It is neither logged nor written
    // to SharedPreferences. Clear the native cache if Drive rejects the token;
    // the next scheduled run will ask the native SDK for a fresh one.
    return _NativeBearerTokenClient(
      accessToken,
      onUnauthorized: () => _clearNativeToken(accessToken),
    );
  }

  Future<void> _clearNativeToken(String accessToken) async {
    try {
      await _backgroundAuthorizationChannel.invokeMethod<void>(
        'clearAuthorizationToken',
        <String, Object?>{'accessToken': accessToken},
      );
    } catch (_) {
      // A cache-clear failure must not mask the original Drive API response.
    }
  }

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
    final pinnedAccountId = _pinnedAccountId;
    if (pinnedAccountId != null && account.id != pinnedAccountId) {
      throw const CloudAuthorizationUnavailable(
        'The selected Google account does not match the account whose backup '
        'is being synchronized.',
      );
    }
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

class _NativeBearerTokenClient extends http.BaseClient {
  _NativeBearerTokenClient(
    this._accessToken, {
    required Future<void> Function() onUnauthorized,
  }) : _onUnauthorized = onUnauthorized;

  final String _accessToken;
  final Future<void> Function() _onUnauthorized;
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    request.headers['authorization'] = 'Bearer $_accessToken';
    final response = await _inner.send(request);
    if (response.statusCode == 401) {
      // Google documents that a cached access token can become invalid before
      // its nominal expiry. Clearing it allows the next authorization request
      // to fetch a replacement without persisting the token locally.
      unawaited(_onUnauthorized());
    }
    return response;
  }

  @override
  void close() {
    _inner.close();
  }
}

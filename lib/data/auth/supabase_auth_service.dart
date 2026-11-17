import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../powersync/powersync_config.dart';
import '../powersync/powersync_database.dart';
import '../powersync/supabase_connector.dart';
import '../../domain/entities/local_account.dart';

/// Result snapshot of an authentication operation.
class AuthOperationResult {
  const AuthOperationResult.success({this.user, this.session})
      : isSuccess = true,
        errorMessage = null;

  const AuthOperationResult.failure(this.errorMessage)
      : isSuccess = false,
        user = null,
        session = null;

  final bool isSuccess;
  final User? user;
  final Session? session;
  final String? errorMessage;
}

/// Provides authentication capabilities backed by Supabase Auth and PowerSync.
class SupabaseAuthService {
  SupabaseAuthService({
    SupabaseClient? client,
    QazaSupabaseConnector? connector,
  })  : _client = client,
        _connector = connector ?? QazaSupabaseConnector();

  final SupabaseClient? _client;
  final QazaSupabaseConnector _connector;

  SupabaseClient? get _activeClient {
    if (_client != null) return _client;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  bool get isSupported => PowerSyncConfig.hasValidCredentials;

  User? get currentUser => _activeClient?.auth.currentUser;
  Session? get currentSession => _activeClient?.auth.currentSession;
  bool get isSignedIn => currentUser != null && currentSession != null;

  Stream<AuthState>? get authStateChanges =>
      _activeClient?.auth.onAuthStateChange;

  /// Signs in with Email and Password.
  Future<AuthOperationResult> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final client = _activeClient;
    if (client == null) {
      return const AuthOperationResult.failure(
        'Supabase client is not initialized.',
      );
    }
    try {
      final response = await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      if (response.user != null) {
        try {
          final wsId = supabaseLocalWorkspaceId(response.user!.id);
          await QazaPowerSyncDatabaseManager.connect(_connector, workspaceId: wsId);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[SupabaseAuthService] PowerSync connect error: $e');
          }
        }
        return AuthOperationResult.success(
          user: response.user,
          session: response.session,
        );
      }
      return const AuthOperationResult.failure(
        'Authentication returned no user.',
      );
    } on AuthException catch (e) {
      return AuthOperationResult.failure(e.message);
    } catch (e) {
      return AuthOperationResult.failure(e.toString());
    }
  }

  /// Creates a new user account with Email and Password.
  Future<AuthOperationResult> signUp({
    required String email,
    required String password,
  }) async {
    final client = _activeClient;
    if (client == null) {
      return const AuthOperationResult.failure(
        'Supabase client is not initialized.',
      );
    }
    try {
      final response = await client.auth.signUp(
        email: email.trim(),
        password: password,
      );
      if (response.user != null) {
        if (response.session != null) {
          try {
            final wsId = supabaseLocalWorkspaceId(response.user!.id);
            await QazaPowerSyncDatabaseManager.connect(_connector, workspaceId: wsId);
          } catch (e) {
            if (kDebugMode) {
              debugPrint('[SupabaseAuthService] PowerSync connect error: $e');
            }
          }
        }
        return AuthOperationResult.success(
          user: response.user,
          session: response.session,
        );
      }
      return const AuthOperationResult.failure(
        'Registration returned no user.',
      );
    } on AuthException catch (e) {
      return AuthOperationResult.failure(e.message);
    } catch (e) {
      return AuthOperationResult.failure(e.toString());
    }
  }

  /// Initiates sign-in using an OAuth Provider (e.g. Google).
  Future<bool> signInWithOAuth(OAuthProvider provider) async {
    final client = _activeClient;
    if (client == null) return false;
    try {
      return await client.auth.signInWithOAuth(provider);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SupabaseAuthService] OAuth error: $e');
      }
      return false;
    }
  }

  /// Signs in natively using a Google ID token and access token without opening a web browser.
  Future<AuthOperationResult> signInWithGoogleNative({
    required String idToken,
    String? accessToken,
  }) async {
    final client = _activeClient;
    if (client == null) {
      return const AuthOperationResult.failure(
        'Supabase client is not initialized.',
      );
    }
    try {
      final response = await client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
      if (response.user != null) {
        if (response.session != null) {
          try {
            final wsId = supabaseLocalWorkspaceId(response.user!.id);
            await QazaPowerSyncDatabaseManager.connect(_connector, workspaceId: wsId);
          } catch (e) {
            if (kDebugMode) {
              debugPrint('[SupabaseAuthService] PowerSync connect error: $e');
            }
          }
        }
        return AuthOperationResult.success(
          user: response.user,
          session: response.session,
        );
      }
      return const AuthOperationResult.failure(
        'Google authentication returned no user.',
      );
    } on AuthException catch (e) {
      return AuthOperationResult.failure(e.message);
    } catch (e) {
      return AuthOperationResult.failure(e.toString());
    }
  }

  /// Signs out of the current Supabase session.
  ///
  /// Disconnects replication streams and closes the database handle while preserving
  /// the separate account's encrypted database and pending offline CRUD mutations
  /// so that offline prayers are never destroyed by signing out.
  Future<void> signOut({String? workspaceId}) async {
    final client = _activeClient;
    try {
      if (client != null) {
        await client.auth.signOut();
      }
    } finally {
      await QazaPowerSyncDatabaseManager.disconnect(
        workspaceId: workspaceId,
      );
      await QazaPowerSyncDatabaseManager.closeDatabase(
        workspaceId: workspaceId,
      );
    }
  }

  /// Explicitly purges replication and cached data upon permanent account deletion or reset.
  Future<void> purgeWorkspaceOnAccountDeletion({required String workspaceId}) async {
    await QazaPowerSyncDatabaseManager.disconnectAndClear(
      workspaceId: workspaceId,
      clearLocal: true,
    );
  }
}

/// Riverpod provider exposing [SupabaseAuthService].
final supabaseAuthServiceProvider = Provider<SupabaseAuthService>((ref) {
  final connector = ref.watch(powerSyncConnectorProvider);
  return SupabaseAuthService(connector: connector);
});

/// Riverpod stream provider for Supabase Auth state changes.
final supabaseAuthStateStreamProvider = StreamProvider<AuthState>((ref) {
  final authService = ref.watch(supabaseAuthServiceProvider);
  return authService.authStateChanges ?? const Stream.empty();
});

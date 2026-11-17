import 'package:flutter/foundation.dart';

/// Configuration and credential placeholders for Supabase and PowerSync.
///
/// Service-role keys, database passwords, and JWT secrets must NEVER be stored
/// in client source code. Public keys (Supabase Publishable/Anon Key) are configured via
/// build-time `--dart-define` or defaulted for local development.
class PowerSyncConfig {
  PowerSyncConfig._();

  /// Supabase Project URL.
  /// Override at build time with `--dart-define=SUPABASE_URL=...`
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://qaza-api.duckdns.org',
  );

  /// Supabase Publishable / Anon Key (safe for client apps, protected by RLS).
  /// Override at build time with `--dart-define=SUPABASE_ANON_KEY=...`
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAgICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE',
  );

  /// Preferred Supabase publishable key alias.
  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: supabaseAnonKey,
  );

  /// PowerSync Service Endpoint (Self-Hosted on Oracle Cloud).
  /// Override at build time with `--dart-define=POWERSYNC_ENDPOINT=...`
  static const String powerSyncEndpoint = String.fromEnvironment(
    'POWERSYNC_ENDPOINT',
    defaultValue: 'https://qaza-sync.duckdns.org',
  );

  /// Supabase JWKS URL for token validation.
  static const String supabaseJwksUrl =
      'https://willvonrjbtvfqvmfwam.supabase.co/auth/v1/.well-known/jwks.json';

  /// Google OAuth Web Client ID (used as serverClientId on Android for Native Sign-In).
  /// Override at build time with `--dart-define=GOOGLE_SERVER_CLIENT_ID=...`
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '895430705174-alhhbpbn958gt8t7e3d0mr3bqogo19sv.apps.googleusercontent.com',
  );

  /// Whether HTTPS transport security has been explicitly verified on the backend.
  /// In Phase 3C (Controlled Multi-Device Cloud Synchronization), HTTPS has been
  /// strictly verified on both DuckDNS endpoints (qaza-api & qaza-sync).
  static bool transportSecurityVerified = true;

  /// Validates whether a given endpoint uses transport-layer encryption (HTTPS/WSS).
  static bool isTransportSecure(String url) {
    final lower = url.trim().toLowerCase();
    return lower.startsWith('https://') || lower.startsWith('wss://');
  }

  /// Enforces transport security for production/release builds.
  /// Cleartext HTTP or WS URLs will throw a [StateError] in release mode.
  static void validateTransportSecurity(String url, {bool isReleaseMode = kReleaseMode}) {
    final lower = url.trim().toLowerCase();
    if (isReleaseMode && (lower.startsWith('http://') || lower.startsWith('ws://'))) {
      throw StateError(
        'Transport security violation: Cleartext HTTP/WS endpoint ($url) is prohibited in release builds. HTTPS/WSS is strictly required.',
      );
    }
  }

  /// Validates whether the active configuration has real (non-empty, non-placeholder) credentials.
  static bool get hasValidCredentials {
    if (supabaseUrl.isEmpty ||
        supabaseUrl.contains('placeholder') ||
        supabasePublishableKey.isEmpty ||
        supabasePublishableKey.contains('placeholder') ||
        powerSyncEndpoint.isEmpty ||
        powerSyncEndpoint.contains('placeholder')) {
      return false;
    }
    if (kReleaseMode &&
        (!isTransportSecure(supabaseUrl) || !isTransportSecure(powerSyncEndpoint))) {
      return false;
    }
    return true;
  }

  /// Dedicated developer/test workspace identifier authorized for Phase 3C.
  static const String developerTestWorkspaceId = String.fromEnvironment(
    'POWERSYNC_TEST_WORKSPACE_ID',
    defaultValue: 'google_developer_test',
  );

  /// Dedicated developer Supabase Auth UUID corresponding to the authorized test workspace.
  static const String developerTestSupabaseUserId = String.fromEnvironment(
    'POWERSYNC_TEST_USER_ID',
    defaultValue: '01138602-ccd5-4c3f-94cf-8935347face7',
  );

  /// In-memory set of workspaces authorized for cloud sync testing.
  /// In Phase 3C, exactly ONE dedicated developer workspace is authorized.
  static final Set<String> _authorizedTestWorkspaces = <String>{
    developerTestWorkspaceId,
    developerTestSupabaseUserId,
  };

  /// Authorizes a workspace for cloud sync testing.
  /// If [verifyTransport] is true, sets [transportSecurityVerified] to true.
  static void authorizeWorkspaceForTesting(
    String workspaceId, {
    bool verifyTransport = false,
  }) {
    if (verifyTransport) {
      transportSecurityVerified = true;
    }
    _authorizedTestWorkspaces.add(workspaceId);
  }

  /// Resets test workspace authorizations to the baseline contained state (no cloud sync).
  static void resetAuthorizedWorkspacesForTesting() {
    transportSecurityVerified = false;
    _authorizedTestWorkspaces.clear();
  }

  /// Restores Phase 3C controlled developer access (exactly one developer workspace authorized).
  static void restoreControlledDeveloperAccess() {
    transportSecurityVerified = true;
    _authorizedTestWorkspaces
      ..clear()
      ..add(developerTestWorkspaceId)
      ..add(developerTestSupabaseUserId);
  }

  /// Evaluates whether cloud synchronization is authorized for [workspaceId].
  ///
  /// In Phase 3B.2 (Immediate Containment & Controlled Sync):
  /// - If [transportSecurityVerified] is false, returns false for all workspaces.
  /// - Guest mode is NEVER authorized (returns false).
  /// - Workspaces must be explicitly added to [_authorizedTestWorkspaces].
  static bool isWorkspaceAuthorizedForCloudSync(String? workspaceId) {
    if (!transportSecurityVerified) return false;
    if (workspaceId == null || workspaceId.isEmpty) return false;
    if (workspaceId == 'guest' ||
        workspaceId.startsWith('guest_') ||
        workspaceId.startsWith('guest:')) {
      return false;
    }
    final normalized = workspaceId.trim();
    if (_authorizedTestWorkspaces.contains(normalized)) return true;
    if (_authorizedTestWorkspaces.contains('google_$normalized')) return true;
    final stripped = normalized.startsWith('google_')
        ? normalized.substring('google_'.length)
        : normalized.startsWith('supabase_')
            ? normalized.substring('supabase_'.length)
            : normalized;
    return _authorizedTestWorkspaces.contains(stripped);
  }
}

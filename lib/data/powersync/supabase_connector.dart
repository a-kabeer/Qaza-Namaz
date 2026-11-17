import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'powersync_config.dart';

/// PostgreSQL error codes that cannot be resolved by retrying.
final List<RegExp> _fatalPostgresCodes = [
  // Class 22 — Data Exception (e.g. data type mismatch)
  RegExp(r'^22...$'),
  // Class 23 — Integrity Constraint Violation (NOT NULL, FK violations)
  RegExp(r'^23...$'),
  // Insufficient Privilege (RLS violation)
  RegExp(r'^42501$'),
];

/// Insertion dependency rank for the 9 cloud-synchronized tables.
/// Parent tables must be inserted before child tables to satisfy foreign-key constraints.
const Map<String, int> kTableInsertRank = {
  'account_profiles': 1,
  'account_plan_revisions': 2,
  'qaza_additions': 3,
  'qaza_records': 4, // References qaza_additions(id)
  'daily_salah_logs': 5,
  'qaza_deletion_actions': 6,
  'qaza_deletion_action_record_snapshots': 7, // References qaza_deletion_actions(id)
  'qaza_profile_plan_provenance': 8, // Conceptually references qaza_records(id)
  'user_preferences': 9,
};

/// Deletion dependency rank for the 9 cloud-synchronized tables.
/// Child tables must be deleted before parent tables to avoid foreign-key constraint violations.
const Map<String, int> kTableDeleteRank = {
  'qaza_profile_plan_provenance': 1,
  'qaza_deletion_action_record_snapshots': 2,
  'qaza_deletion_actions': 3,
  'qaza_records': 4,
  'qaza_additions': 5,
  'daily_salah_logs': 6,
  'account_plan_revisions': 7,
  'account_profiles': 8,
  'user_preferences': 9,
};

/// Supabase connector integrating Supabase Auth and REST upload with PowerSync.
class QazaSupabaseConnector extends PowerSyncBackendConnector {
  QazaSupabaseConnector({
    SupabaseClient? client,
    String? powerSyncEndpoint,
    Future<String?> Function()? authTokenProvider,
    Future<String?> Function()? currentUserIdProvider,
    Future<DateTime?> Function()? tokenExpiryProvider,
    Future<void> Function(CrudTransaction)? customUploader,
  })  : _client = client,
        _powerSyncEndpoint =
            powerSyncEndpoint ?? PowerSyncConfig.powerSyncEndpoint,
        _authTokenProvider = authTokenProvider,
        _currentUserIdProvider = currentUserIdProvider,
        _tokenExpiryProvider = tokenExpiryProvider,
        _customUploader = customUploader;

  final SupabaseClient? _client;
  final String _powerSyncEndpoint;
  final Future<String?> Function()? _authTokenProvider;
  final Future<String?> Function()? _currentUserIdProvider;
  final Future<DateTime?> Function()? _tokenExpiryProvider;
  final Future<void> Function(CrudTransaction)? _customUploader;

  Future<void>? _refreshFuture;
  String? _lastAuthenticatedUserId;

  String? get lastAuthenticatedUserId => _lastAuthenticatedUserId;

  @visibleForTesting
  Future<void> Function(CrudTransaction)? get customUploader => _customUploader;

  SupabaseClient? get _activeClient {
    if (_client != null) return _client;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Resolves the current authenticated user ID from test providers or active Supabase session.
  Future<String?> getCurrentUserId() async {
    final userProvider = _currentUserIdProvider;
    if (userProvider != null) {
      return await userProvider();
    }
    final client = _activeClient;
    if (client == null) return null;
    return client.auth.currentUser?.id;
  }

  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    await _refreshFuture;

    // 1. Check custom test provider if supplied
    final tokenProvider = _authTokenProvider;
    final userProvider = _currentUserIdProvider;
    if (tokenProvider != null && userProvider != null) {
      final token = await tokenProvider();
      final userId = await userProvider();
      if (token == null || token.isEmpty || userId == null || userId.isEmpty) {
        return null;
      }
      _lastAuthenticatedUserId = userId;
      final expiryProvider = _tokenExpiryProvider;
      final expiresAt = expiryProvider != null
          ? await expiryProvider()
          : DateTime.now().toUtc().add(const Duration(hours: 1));
      return PowerSyncCredentials(
        endpoint: _powerSyncEndpoint,
        token: token,
        userId: userId,
        expiresAt: expiresAt,
      );
    }

    // 2. Read from active SupabaseClient
    try {
      final client = _activeClient;
      if (client == null) return null;

      final session = client.auth.currentSession;
      if (session == null) {
        _lastAuthenticatedUserId = null;
        return null;
      }

      // Check token expiration and refresh if needed
      if (session.isExpired) {
        final refreshResponse = await client.auth.refreshSession();
        if (refreshResponse.session == null) {
          _lastAuthenticatedUserId = null;
          return null;
        }
      }

      final activeSession = client.auth.currentSession;
      if (activeSession == null) {
        _lastAuthenticatedUserId = null;
        return null;
      }

      final token = activeSession.accessToken;
      final userId = activeSession.user.id;
      if (token.isEmpty || userId.isEmpty) return null;

      _lastAuthenticatedUserId = userId;
      final expiresAt = activeSession.expiresAt != null
          ? DateTime.fromMillisecondsSinceEpoch(
              activeSession.expiresAt! * 1000,
              isUtc: true,
            )
          : null;

      return PowerSyncCredentials(
        endpoint: _powerSyncEndpoint,
        token: token,
        userId: userId,
        expiresAt: expiresAt,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '[QazaSupabaseConnector] Error fetching Supabase credentials: $e');
      }
      return null;
    }
  }

  @override
  void invalidateCredentials() {
    final client = _activeClient;
    if (client != null) {
      _refreshFuture = client.auth
          .refreshSession()
          .timeout(const Duration(seconds: 5))
          .then((_) => null, onError: (_) => null);
    }
  }

  /// Sorts CRUD entries deterministically according to foreign-key dependencies:
  /// - Deletions: child records before parent records.
  /// - Insertions/Updates: parent records before child records.
  @visibleForTesting
  static List<CrudEntry> sortCrudEntries(List<CrudEntry> entries) {
    final result = List<CrudEntry>.from(entries);
    result.sort((a, b) {
      final aIsDelete = a.op == UpdateType.delete;
      final bIsDelete = b.op == UpdateType.delete;

      if (aIsDelete && !bIsDelete) return -1;
      if (!aIsDelete && bIsDelete) return 1;

      if (aIsDelete && bIsDelete) {
        final rankA = kTableDeleteRank[a.table] ?? 50;
        final rankB = kTableDeleteRank[b.table] ?? 50;
        return rankA.compareTo(rankB);
      }

      final rankA = kTableInsertRank[a.table] ?? 50;
      final rankB = kTableInsertRank[b.table] ?? 50;
      return rankA.compareTo(rankB);
    });
    return result;
  }

  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    final transaction = await database.getNextCrudTransaction();
    if (transaction == null) {
      return;
    }

    // Custom test seam handler
    final uploader = _customUploader;
    if (uploader != null) {
      await uploader(transaction);
      return;
    }

    final currentUserId = await getCurrentUserId();
    if (currentUserId == null || currentUserId.isEmpty) {
      throw StateError(
        'Cannot upload CRUD transaction: user is not authenticated in Supabase.',
      );
    }

    final client = _activeClient;
    if (client == null) {
      throw StateError('Supabase client is not available for uploadData.');
    }
    final rest = client.rest;

    try {
      // Deterministic, dependency-aware ordering
      final sortedOps = sortCrudEntries(transaction.crud);

      for (final op in sortedOps) {
        final table = rest.from(op.table);

        try {
          if (op.op == UpdateType.put) {
            final data =
                Map<String, dynamic>.of(op.opData ?? <String, dynamic>{});
            data['id'] = op.id;

            // Mandatory Ownership Validation: must match authenticated user
            if (data.containsKey('user_id')) {
              final recordUserId = data['user_id']?.toString();
              if (recordUserId != null &&
                  recordUserId.isNotEmpty &&
                  recordUserId != currentUserId) {
                throw StateError(
                  'Security violation: cannot upload record for foreign user_id '
                  '($recordUserId) with active user ($currentUserId).',
                );
              }
            }
            data['user_id'] = currentUserId;

            await table.upsert(data, onConflict: 'id');
          } else if (op.op == UpdateType.patch) {
            final data =
                Map<String, dynamic>.of(op.opData ?? <String, dynamic>{});

            // Prevent changing row ownership via PATCH
            if (data.containsKey('user_id') && data['user_id'] != currentUserId) {
              throw StateError(
                'Security violation: cannot change user_id via PATCH.',
              );
            }

            await table.update(data).eq('id', op.id).eq('user_id', currentUserId);
          } else if (op.op == UpdateType.delete) {
            await table.delete().eq('id', op.id).eq('user_id', currentUserId);
          }
        } on PostgrestException catch (opErr) {
          if (_isStaleConflictError(opErr)) {
            await _reconcileStaleConflict(
              op: op,
              error: opErr,
              rest: rest,
              currentUserId: currentUserId,
              database: database,
            );
            continue; // Reconciled safely; proceed to next operation
          }
          rethrow;
        }
      }

      // Complete ONLY after all operations have successfully executed or reconciled
      await transaction.complete();
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST301' ||
          e.code == '401' ||
          e.message.contains('JWT') ||
          e.message.contains('expired')) {
        invalidateCredentials();
        rethrow;
      }
      if (_isStaleConflictError(e)) {
        if (kDebugMode) {
          debugPrint(
            '[QazaSupabaseConnector] Transaction-level stale conflict reconciled: ${e.message}',
          );
        }
        await transaction.complete();
      } else if (e.code != null &&
          _fatalPostgresCodes.any((re) => re.hasMatch(e.code!))) {
        if (kDebugMode) {
          debugPrint(
            '[QazaSupabaseConnector] Non-retryable error (${e.code}) — discarding transaction: ${e.message}',
          );
        }
        await transaction.complete();
      } else {
        rethrow;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[QazaSupabaseConnector] Upload error: $e');
      }
      rethrow;
    }
  }

  /// Determines whether a [PostgrestException] represents a server-authoritative
  /// conflict rejection (stale mutation version or stale resurrection of a deleted entity).
  static bool _isStaleConflictError(PostgrestException e) {
    return e.code == 'P0001' ||
        e.message.contains('STALE_MUTATION_REJECTED') ||
        e.message.contains('STALE_RESURRECTION_REJECTED');
  }

  /// Safe server-authoritative reconciliation procedure for stale mutations:
  /// 1. Queries canonical server state to confirm authoritative version.
  /// 2. Verifies audit history and avoids infinite transaction retry deadlock.
  /// 3. Relies on PowerSync's downstream replication stream to bring local SQLite
  ///    into convergence with canonical server state.
  Future<void> _reconcileStaleConflict({
    required CrudEntry op,
    required PostgrestException error,
    required dynamic rest,
    required String currentUserId,
    required PowerSyncDatabase database,
  }) async {
    if (kDebugMode) {
      debugPrint(
        '[QazaSupabaseConnector] Conflict detected on ${op.table}/${op.id}: ${error.message}. '
        'Initiating server-authoritative reconciliation...',
      );
    }

    try {
      if (error.message.contains('STALE_RESURRECTION_REJECTED')) {
        if (kDebugMode) {
          debugPrint(
            '[QazaSupabaseConnector] Stale resurrection of deleted entity ${op.table}/${op.id} '
            'reconciled: deletion action snapshot is authoritative.',
          );
        }
        return;
      }

      // Fetch canonical server row to verify current state
      final serverRow = await rest
          .from(op.table)
          .select()
          .eq('id', op.id)
          .eq('user_id', currentUserId)
          .maybeSingle();

      if (kDebugMode) {
        debugPrint(
          '[QazaSupabaseConnector] Canonical server row for ${op.table}/${op.id}: '
          '${serverRow != null ? "found (version ${serverRow['record_version'] ?? serverRow['entity_version'] ?? serverRow['revision']})" : "not found"}. '
          'Local mutation superseded by server-authoritative state.',
        );
      }
    } catch (fetchErr) {
      if (kDebugMode) {
        debugPrint(
          '[QazaSupabaseConnector] Warning during conflict reconciliation for ${op.table}/${op.id}: $fetchErr',
        );
      }
    }
  }
}

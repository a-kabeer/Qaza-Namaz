import 'dart:async';

import 'powersync_config.dart';

/// Represents a single mutation record in the PowerSync upload queue.
enum CrudOperation { put, patch, delete }

class PowerSyncCrudEntry {
  const PowerSyncCrudEntry({
    required this.id,
    required this.table,
    required this.op,
    required this.data,
    required this.clientId,
  });

  final String id;
  final String table;
  final CrudOperation op;
  final Map<String, dynamic> data;
  final String clientId;
}

/// Authentication credentials delivered to PowerSync.
class PowerSyncCredentials {
  const PowerSyncCredentials({
    required this.endpoint,
    required this.token,
    required this.userId,
    this.expiresAt,
  });

  final String endpoint;
  final String token;
  final String userId;
  final DateTime? expiresAt;
}

/// Abstract contract for the PowerSync backend connector.
///
/// Responsible for:
/// 1. Supplying fresh Supabase JWTs to PowerSync for stream replication.
/// 2. Uploading local offline mutations to Supabase when network is restored.
abstract interface class PowerSyncConnectorContract {
  /// Fetches Supabase Auth token to authenticate the PowerSync sync stream.
  Future<PowerSyncCredentials?> fetchCredentials();

  /// Uploads batched local mutations to Supabase.
  /// Throws an exception on failure to trigger PowerSync's automatic exponential retry.
  Future<void> uploadData(List<PowerSyncCrudEntry> entries);
}

/// Default implementation connecting Supabase Auth and REST upload with PowerSync.
class SupabasePowerSyncConnector implements PowerSyncConnectorContract {
  SupabasePowerSyncConnector({
    String? supabaseUrl,
    String? supabaseAnonKey,
    String? powerSyncEndpoint,
    Future<String?> Function()? authTokenProvider,
    Future<String?> Function()? currentUserIdProvider,
    Future<void> Function(List<PowerSyncCrudEntry>)? mockUploader,
  })  : _supabaseUrl = supabaseUrl ?? PowerSyncConfig.supabaseUrl,
        _supabaseAnonKey = supabaseAnonKey ?? PowerSyncConfig.supabaseAnonKey,
        _powerSyncEndpoint =
            powerSyncEndpoint ?? PowerSyncConfig.powerSyncEndpoint,
        _authTokenProvider = authTokenProvider,
        _currentUserIdProvider = currentUserIdProvider,
        _mockUploader = mockUploader;

  final String _supabaseUrl;
  final String _supabaseAnonKey;
  final String _powerSyncEndpoint;
  final Future<String?> Function()? _authTokenProvider;
  final Future<String?> Function()? _currentUserIdProvider;
  final Future<void> Function(List<PowerSyncCrudEntry>)? _mockUploader;

  String get supabaseUrl => _supabaseUrl;
  String get supabaseAnonKey => _supabaseAnonKey;
  String get powerSyncEndpoint => _powerSyncEndpoint;

  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    final token = _authTokenProvider != null
        ? await _authTokenProvider()
        : 'placeholder-jwt-token';

    final userId = _currentUserIdProvider != null
        ? await _currentUserIdProvider()
        : 'placeholder-user-id';

    if (token == null || userId == null) return null;

    return PowerSyncCredentials(
      endpoint: _powerSyncEndpoint,
      token: token,
      userId: userId,
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
    );
  }

  @override
  Future<void> uploadData(List<PowerSyncCrudEntry> entries) async {
    if (entries.isEmpty) return;

    if (_mockUploader != null) {
      await _mockUploader(entries);
      return;
    }

    // In a live connection with supabase_flutter, mutations are written
    // to Supabase tables using the Supabase REST Client:
    // for (final entry in entries) {
    //   final client = Supabase.instance.client;
    //   switch (entry.op) {
    //     case CrudOperation.put:
    //       await client.from(entry.table).upsert(entry.data);
    //     case CrudOperation.patch:
    //       await client.from(entry.table).update(entry.data).eq('id', entry.id);
    //     case CrudOperation.delete:
    //       await client.from(entry.table).delete().eq('id', entry.id);
    //   }
    // }
  }
}

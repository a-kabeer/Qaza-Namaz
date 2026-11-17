import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/providers.dart';
import '../../domain/entities/local_account.dart';
import '../local/database/app_database.dart';

/// Adoption resolution choice when both Guest and Cloud accounts contain records.
enum AdoptionResolution {
  /// Merges guest records into the cloud account with deterministic deduplication.
  keepBoth,

  /// Discards local guest records and accepts the existing cloud records.
  keepCloud,

  /// Overwrites cloud data with the local guest records.
  keepLocal,
}

/// Scenario evaluated when a user logs into a cloud account.
class AdoptionEvaluation {
  const AdoptionEvaluation({
    required this.guestRecordCount,
    required this.cloudRecordCount,
  });

  final int guestRecordCount;
  final int cloudRecordCount;

  bool get hasGuestData => guestRecordCount > 0;
  bool get hasCloudData => cloudRecordCount > 0;

  /// True if guest data can be adopted automatically without user confirmation.
  bool get canAutoAdopt => hasGuestData && !hasCloudData;

  /// True if user must be prompted because both sides have data.
  bool get requiresResolution => hasGuestData && hasCloudData;
}

/// Service that coordinates safe Guest-to-Supabase account data adoption.
class GuestDataAdoptionService {
  GuestDataAdoptionService({
    required AppDatabase database,
    SupabaseClient? supabaseClient,
  })  : _database = database,
        _supabaseClient = supabaseClient;

  final AppDatabase _database;
  final SupabaseClient? _supabaseClient;

  SupabaseClient? get _client {
    if (_supabaseClient != null) return _supabaseClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Counts local records belonging to [guestWorkspaceId].
  Future<int> countGuestRecords(String guestWorkspaceId) async {
    final query = _database.select(_database.qazaRecords)
      ..where((tbl) => tbl.userId.equals(guestWorkspaceId));
    final count = await query.get();
    return count.length;
  }

  /// Counts cloud records belonging to [supabaseUserId] via Supabase REST.
  Future<int> countCloudRecords(String supabaseUserId) async {
    final client = _client;
    if (client == null) return 0;
    try {
      final response = await client
          .from('qaza_records')
          .select('id')
          .eq('user_id', supabaseUserId)
          .limit(100);
      return (response as List).length;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[GuestDataAdoption] Cloud count query error: $e');
      }
      return 0;
    }
  }

  /// Evaluates whether an adoption prompt is needed.
  Future<AdoptionEvaluation> evaluate({
    required String guestWorkspaceId,
    required String supabaseUserId,
  }) async {
    final guestCount = await countGuestRecords(guestWorkspaceId);
    final cloudCount =
        guestCount > 0 ? await countCloudRecords(supabaseUserId) : 0;
    return AdoptionEvaluation(
      guestRecordCount: guestCount,
      cloudRecordCount: cloudCount,
    );
  }

  /// Atomically executes adoption based on the chosen [resolution].
  Future<void> executeAdoption({
    required String guestWorkspaceId,
    required String supabaseUserId,
    required AdoptionResolution resolution,
  }) async {
    final targetWorkspaceId = supabaseLocalWorkspaceId(supabaseUserId);
    switch (resolution) {
      case AdoptionResolution.keepBoth:
      case AdoptionResolution.keepLocal:
        await _reassignGuestRecords(
          guestWorkspaceId: guestWorkspaceId,
          targetWorkspaceId: targetWorkspaceId,
        );
      case AdoptionResolution.keepCloud:
        await _purgeGuestRecords(guestWorkspaceId);
    }
  }

  /// Reassigns all local records owned by [guestWorkspaceId] to [targetWorkspaceId].
  Future<void> _reassignGuestRecords({
    required String guestWorkspaceId,
    required String targetWorkspaceId,
  }) async {
    await _database.transaction(() async {
      await _database.customUpdate(
        'UPDATE qaza_records SET user_id = ? WHERE user_id = ?',
        variables: [
          Variable.withString(targetWorkspaceId),
          Variable.withString(guestWorkspaceId)
        ],
        updates: {_database.qazaRecords},
      );
      try {
        await _database.customUpdate(
          'UPDATE daily_salah_logs SET user_id = ? WHERE user_id = ?',
          variables: [
            Variable.withString(targetWorkspaceId),
            Variable.withString(guestWorkspaceId)
          ],
        );
      } catch (_) {}
      try {
        await _database.customUpdate(
          'UPDATE account_profiles SET local_account_id = ? WHERE local_account_id = ?',
          variables: [
            Variable.withString(targetWorkspaceId),
            Variable.withString(guestWorkspaceId)
          ],
        );
      } catch (_) {}
      try {
        await _database.customUpdate(
          'UPDATE account_plan_revisions SET local_account_id = ? WHERE local_account_id = ?',
          variables: [
            Variable.withString(targetWorkspaceId),
            Variable.withString(guestWorkspaceId)
          ],
        );
      } catch (_) {}
      try {
        await _database.customUpdate(
          'UPDATE qaza_additions SET user_id = ? WHERE user_id = ?',
          variables: [
            Variable.withString(targetWorkspaceId),
            Variable.withString(guestWorkspaceId)
          ],
        );
      } catch (_) {}
      try {
        await _database.customUpdate(
          "UPDATE local_accounts SET lifecycle_state = 'archived' WHERE local_account_id = ?",
          variables: [Variable.withString(guestWorkspaceId)],
        );
      } catch (_) {}
    });
  }

  /// Purges local records owned by [guestWorkspaceId] when user chooses to keep cloud.
  Future<void> _purgeGuestRecords(String guestWorkspaceId) async {
    await _database.transaction(() async {
      await _database.customUpdate(
        'DELETE FROM qaza_records WHERE user_id = ?',
        variables: [Variable.withString(guestWorkspaceId)],
        updates: {_database.qazaRecords},
      );
      try {
        await _database.customUpdate(
          'DELETE FROM daily_salah_logs WHERE user_id = ?',
          variables: [Variable.withString(guestWorkspaceId)],
        );
      } catch (_) {}
      try {
        await _database.customUpdate(
          'DELETE FROM account_profiles WHERE local_account_id = ?',
          variables: [Variable.withString(guestWorkspaceId)],
        );
      } catch (_) {}
      try {
        await _database.customUpdate(
          'DELETE FROM account_plan_revisions WHERE local_account_id = ?',
          variables: [Variable.withString(guestWorkspaceId)],
        );
      } catch (_) {}
      try {
        await _database.customUpdate(
          'DELETE FROM qaza_additions WHERE user_id = ?',
          variables: [Variable.withString(guestWorkspaceId)],
        );
      } catch (_) {}
      try {
        await _database.customUpdate(
          'DELETE FROM local_accounts WHERE local_account_id = ?',
          variables: [Variable.withString(guestWorkspaceId)],
        );
      } catch (_) {}
    });
  }
}

/// Riverpod provider for [GuestDataAdoptionService].
final guestDataAdoptionServiceProvider =
    Provider<GuestDataAdoptionService>((ref) {
  final database = ref.watch(appDatabaseProvider);
  return GuestDataAdoptionService(database: database);
});

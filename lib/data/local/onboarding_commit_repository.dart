import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/qaza_plan_revision.dart';
import '../../domain/entities/qaza_record.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/onboarding_commit_repository.dart';
import 'account_local_store.dart';

class AccountLocalOnboardingCommitRepository
    implements OnboardingCommitRepository {
  const AccountLocalOnboardingCommitRepository(this._store);

  final AccountLocalStore _store;

  @override
  Future<void> commit({
    required String localAccountId,
    required UserProfile profile,
    required QazaPlanRevision revision,
    required List<QazaRecord> records,
    void Function(int processed, int total)? onProgress,
  }) async {
    await _store.commitOnboarding(
      localAccountId: localAccountId,
      profile: profile,
      revision: revision,
      records: records,
      onProgress: onProgress,
    );

    // Sync profile to Supabase if authenticated so it survives cache/data wipes
    try {
      SupabaseClient? client;
      try {
        client = Supabase.instance.client;
      } catch (_) {
        client = null;
      }
      final user = client?.auth.currentUser;
      if (user != null) {
        final deviceId = await _store.deviceInstanceId();
        await client!.from('account_profiles').upsert({
          'user_id': user.id,
          'payload_json': profile.toJson(),
          'writer_device_id': deviceId,
          'operation_id': 'op_${DateTime.now().microsecondsSinceEpoch}',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'user_id');

        await client.from('account_plan_revisions').upsert({
          'user_id': user.id,
          'revision_id': revision.revisionId,
          'payload_json': revision.toJson(),
          'created_at': revision.createdAt.toUtc().toIso8601String(),
        }, onConflict: 'user_id,revision_id');

        for (var i = 0; i < records.length; i += 200) {
          final end = (i + 200 < records.length) ? i + 200 : records.length;
          final batch = records.sublist(i, end);
          await client.from('qaza_records').upsert(
            batch
                .map((r) => {
                      'id': r.id,
                      'user_id': user.id,
                      'prayer_type': r.prayerType.name,
                      'original_date':
                          r.originalDate.toIso8601String().substring(0, 10),
                      'status': r.status.name,
                      'completed_at': r.completedAt?.toUtc().toIso8601String(),
                      'completion_id': r.completionId,
                      'addition_id': r.additionId,
                      'record_version': r.recordVersion,
                      'created_at': r.createdAt.toUtc().toIso8601String(),
                      'updated_at': r.updatedAt.toUtc().toIso8601String(),
                    })
                .toList(),
            onConflict: 'user_id,prayer_type,original_date',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[OnboardingCommitRepository] Cloud profile sync error: $e');
      }
    }
  }
}

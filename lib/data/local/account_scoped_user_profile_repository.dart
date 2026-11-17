import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/prayer_types.dart';
import '../../domain/entities/qaza_record.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/user_profile_repository.dart';
import '../../domain/services/profile_qaza_plan_reconciliation_service.dart';
import '../../domain/services/qaza_plan_service.dart';
import 'account_local_store.dart';
import 'database/app_database.dart';

class AccountScopedUserProfileRepository implements UserProfileRepository {
  AccountScopedUserProfileRepository({
    required AccountLocalStore store,
    required String? Function() activeAccountId,
    SupabaseClient? supabaseClient,
  })  : _store = store,
        _activeAccountId = activeAccountId,
        _supabaseClient = supabaseClient;

  final AccountLocalStore _store;
  final String? Function() _activeAccountId;
  final SupabaseClient? _supabaseClient;

  SupabaseClient? get _client {
    if (_supabaseClient != null) return _supabaseClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<UserProfile?> load() async {
    final id = _activeAccountId();
    if (id == null) return null;

    final localProfile = await _store.loadProfile(id);
    if (localProfile != null) {
      await _reconcileLedgerIfMissing(id, localProfile);
      return localProfile;
    }

    // Cloud recovery: If the local database was cleared or we are on a fresh device,
    // query Supabase account_profiles for the authenticated cloud user.
    try {
      final client = _client;
      final user = client?.auth.currentUser;
      if (user != null) {
        final row = await client!
            .from('account_profiles')
            .select('payload_json')
            .eq('user_id', user.id)
            .maybeSingle();

        if (row != null && row['payload_json'] != null) {
          final payload = row['payload_json'];
          final map = payload is String
              ? jsonDecode(payload)
              : Map<String, dynamic>.from(payload as Map);
          final remoteProfile =
              UserProfile.fromJson(Map<String, dynamic>.from(map as Map));
          await _store.saveProfileLocalOnly(id, remoteProfile);
          await _reconcileLedgerIfMissing(id, remoteProfile);
          return remoteProfile;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[UserProfileRepository] Remote profile restore error: $e');
      }
    }

    return null;
  }

  Future<void> _reconcileLedgerIfMissing(String id, UserProfile profile) async {
    try {
      if (!profile.isComplete || !profile.onboardingCompleted) return;
      final hasRecords = await _store.hasQazaRecords(id);
      if (hasRecords) return;

      // 1. Check if Supabase cloud has qaza_records for this authenticated user
      final client = _client;
      final user = client?.auth.currentUser;
      if (user != null) {
        final dynamic remoteRows = await client!
            .from('qaza_records')
            .select()
            .eq('user_id', user.id);
        if (remoteRows is List && remoteRows.isNotEmpty) {
          final workspace =
              await _store.databaseManager.databaseForWorkspace(id);
          for (var i = 0; i < remoteRows.length; i += 200) {
            final end =
                (i + 200 < remoteRows.length) ? i + 200 : remoteRows.length;
            final chunk = remoteRows.sublist(i, end);
            await workspace.qazaRecordsDao
                .insertRecordsReturningInsertedIds([
              for (final raw in chunk)
                QazaRecordsCompanion.insert(
                  id: raw['id'] as String,
                  userId: id,
                  prayerType: raw['prayer_type'] as String,
                  originalDate:
                      DateTime.parse(raw['original_date'] as String),
                  status: raw['status'] as String,
                  completedAt: raw['completed_at'] != null
                      ? Value(DateTime.parse(raw['completed_at'] as String))
                      : const Value.absent(),
                  completionId: raw['completion_id'] != null
                      ? Value(raw['completion_id'] as String)
                      : const Value.absent(),
                  additionId: raw['addition_id'] != null
                      ? Value(raw['addition_id'] as String)
                      : const Value.absent(),
                  recordVersion: Value(
                      (raw['record_version'] as num?)?.toInt() ?? 1),
                  createdAt: raw['created_at'] != null
                      ? DateTime.parse(raw['created_at'] as String)
                      : DateTime.now(),
                  updatedAt: raw['updated_at'] != null
                      ? DateTime.parse(raw['updated_at'] as String)
                      : DateTime.now(),
                ),
            ]);
          }
          return;
        }
      }

      // 3. Fallback: Auto-reconstruct initial plan from the valid profile
      if (profile.isComplete) {
        final plan = QazaPlanService().planFor(profile);
        if (plan != null && plan.totalWithWitr > 0) {
          final revisionId =
              ProfileQazaPlanReconciliationService.newRevisionId();
          final dates = QazaPlanService.datesFor(plan);
          final fingerprint =
              ProfileQazaPlanReconciliationService.planFingerprint(plan);
          final prayerTypes = [
            PrayerType.fajr,
            PrayerType.zuhr,
            PrayerType.asr,
            PrayerType.maghrib,
            PrayerType.isha,
            if (plan.includeWitr) PrayerType.witr,
          ];
          final records = dates.expand((date) {
            final dateStr = date.toIso8601String().substring(0, 10);
            return prayerTypes.map((prayer) => QazaRecord(
                  id: '${dateStr}_${prayer.name}',
                  userId: id,
                  prayerType: prayer,
                  originalDate: date,
                  status: QazaStatus.pending,
                  profilePlanRevisionId: revisionId,
                  profilePlanFingerprint: fingerprint,
                  recordVersion: 1,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                ));
          }).toList();

          final revision =
              ProfileQazaPlanReconciliationService.createInitialRevision(
            revisionId: revisionId,
            userId: id,
            profile: profile,
            plan: plan,
            addedRecords: records.length,
          );

          await _store.commitOnboarding(
            localAccountId: id,
            profile: profile,
            revision: revision,
            records: records,
          );

          if (client != null && user != null) {
            try {
              await client.from('account_plan_revisions').upsert({
                'user_id': user.id,
                'revision_id': revision.revisionId,
                'payload_json': revision.toJson(),
                'created_at': revision.createdAt.toUtc().toIso8601String(),
              }, onConflict: 'user_id,revision_id');

              for (var i = 0; i < records.length; i += 200) {
                final end = (i + 200 < records.length)
                    ? i + 200
                    : records.length;
                final batch = records.sublist(i, end);
                await client.from('qaza_records').upsert(
                  batch
                      .map((r) => {
                            'id': r.id,
                            'user_id': user.id,
                            'prayer_type': r.prayerType.name,
                            'original_date': r.originalDate
                                .toIso8601String()
                                .substring(0, 10),
                            'status': r.status.name,
                            'completed_at':
                                r.completedAt?.toUtc().toIso8601String(),
                            'completion_id': r.completionId,
                            'addition_id': r.additionId,
                            'record_version': r.recordVersion,
                            'created_at':
                                r.createdAt.toUtc().toIso8601String(),
                            'updated_at':
                                r.updatedAt.toUtc().toIso8601String(),
                          })
                      .toList(),
                  onConflict: 'user_id,prayer_type,original_date',
                );
              }
            } catch (cloudErr) {
              if (kDebugMode) {
                debugPrint(
                    '[UserProfileRepository] Reconcile cloud upload error: $cloudErr');
              }
            }
          }
        }
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint(
            '[UserProfileRepository] _reconcileLedgerIfMissing error: $e\n$st');
      }
    }
  }

  @override
  Future<void> save(UserProfile profile) async {
    final id = _activeAccountId();
    if (id == null) {
      throw StateError('No active local account exists.');
    }
    await _store.saveProfile(id, profile);
    await _syncToSupabase(profile);
  }

  @override
  Future<void> saveLocalOnly(UserProfile profile) async {
    final id = _activeAccountId();
    if (id == null) {
      throw StateError('No active local account exists.');
    }
    await _store.saveProfileLocalOnly(id, profile);
  }

  @override
  Future<void> clear() async {
    final id = _activeAccountId();
    if (id == null) return;
    final ownerCol =
        await _store.resolveOwnerColumn(_store.database, 'account_profiles');
    await _store.database.customUpdate(
      'DELETE FROM account_profiles WHERE $ownerCol = ?',
      variables: [Variable(id)],
    );
  }

  Future<void> _syncToSupabase(UserProfile profile) async {
    try {
      final client = _client;
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
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '[UserProfileRepository] Supabase cloud profile save error: $e');
      }
    }
  }
}

import 'dart:convert';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qaza_cloud_adapter/qaza_cloud_adapter.dart';
import 'package:qaza_namaz/data/data_transfer/local_backup_service.dart';
import 'package:qaza_namaz/data/local/account_local_store.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/domain/services/cloud_sync_contracts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Scenario 11 (expired / revoked token) at the provider level.
///
/// The gateway still hands out a client, but Drive rejects every request
/// with HTTP 401 — the classic expired-token shape. The specified
/// behaviour is that the workspace sync state becomes `needs_sign_in`
/// (the state that exists in `AppDatabase.writeWorkspaceSyncState`'s
/// valid set and blocks uploads via `isWorkspaceCloudUploadBlocked`),
/// while the local workspace keeps opening and reading normally.
///
/// The first test pins the safety invariants that hold today. The second
/// pins the `needs_sign_in` transition itself; see the report for its
/// current result.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const accountId = 'google-account-A';
  const workspaceId = 'google_google-account-A';
  const localRecordId = 'google-account-A_fajr_2026-10-01';

  late AppDatabase database;
  late SharedPreferencesCloudSyncStateStore state;
  var postCount = 0;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    database = AppDatabase(NativeDatabase.memory());
    final store = AccountLocalStore(database: database);
    await store.ensureInitialized();
    await store.ensureAccountActive(workspaceId);
    await database.qazaRecordsDao.insertRecord(
      QazaRecordsCompanion.insert(
        id: localRecordId,
        userId: workspaceId,
        prayerType: 'fajr',
        originalDate: DateTime(2026, 10, 1),
        status: 'pending',
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 1),
      ),
    );
    await database.writeWorkspaceSyncState(workspaceId, 'clean');
    state = SharedPreferencesCloudSyncStateStore(preferences: preferences);
    await state.setActiveAccountId(accountId);
    await state.setCloudSyncEnabled(true);
    postCount = 0;
  });

  tearDown(() async {
    await database.close();
  });

  GoogleCloudSyncProvider buildProvider() {
    return GoogleCloudSyncProvider(
      database: database,
      gateway: _FakeGateway(
        accountId: accountId,
        handler: (http.BaseRequest request) async {
          if (request.method == 'POST') postCount++;
          return http.Response(
            jsonEncode(<String, Object?>{
              'error': <String, Object?>{
                'code': 401,
                'message': 'Request had invalid authentication credentials.',
                'errors': <Object?>[
                  <String, Object?>{
                    'domain': 'global',
                    'reason': 'authError',
                    'message':
                        'Request had invalid authentication credentials.',
                  },
                ],
              },
            }),
            401,
            headers: const <String, String>{'content-type': 'application/json'},
          );
        },
      ),
      state: state,
      scheduler: _FakeScheduler(state: state),
    );
  }

  Future<List<String>> localRecordIds() async {
    final rows = await database
        .customSelect(
          'SELECT id FROM qaza_records WHERE user_id = ? ORDER BY id',
          variables: [Variable(workspaceId)],
        )
        .get();
    return rows.map((row) => row.read<String>('id')).toList();
  }

  test('a Drive 401 during Backup Now uploads nothing and leaves the local '
      'workspace fully readable', () async {
    final provider = buildProvider();

    final snapshot = await provider.backupNow();

    // The backup is not reported as synced, nothing was uploaded, and the
    // failure must not mark the workspace clean.
    expect(snapshot.status, CloudSyncStatus.failed);
    expect(postCount, 0);
    expect(await database.readWorkspaceSyncState(workspaceId), isNot('clean'));
    // The local workspace still opens and reads normally afterwards: its
    // records are intact and a full local export still works.
    expect(await localRecordIds(), <String>[localRecordId]);
    final export = await LocalBackupService(
      database,
    ).exportJson(localAccountId: workspaceId);
    expect(export, contains(localRecordId));
  });

  test('an expired or revoked token moves the workspace sync state to '
      'needs_sign_in (Scenario 11)', () async {
    final provider = buildProvider();

    final snapshot = await provider.backupNow();

    expect(snapshot.status, CloudSyncStatus.failed);
    // Local data safety holds even on this path.
    expect(await localRecordIds(), <String>[localRecordId]);
    // The specified Scenario 11 outcome: the workspace is parked in
    // needs_sign_in, which blocks further uploads until the user signs in
    // again, instead of silently returning to a retryable state.
    expect(await database.readWorkspaceSyncState(workspaceId), 'needs_sign_in');
  });
}

/// Hands the real Drive store a fresh [MockClient] per authorization, so a
/// client closed after one Drive call never poisons the next one.
class _FakeGateway extends GoogleSignInGateway {
  _FakeGateway({required this.accountId, required this.handler});

  final String accountId;
  final Future<http.Response> Function(http.BaseRequest request) handler;

  @override
  Future<String?> accountIdForAuthorization() async => accountId;

  @override
  Future<http.Client?> authorizeDrive({required bool allowInteractive}) async {
    return MockClient(handler);
  }
}

class _FakeScheduler extends CloudSyncScheduler {
  _FakeScheduler({required CloudSyncStateStore state}) : super(state: state);

  @override
  Future<void> initializeAndSchedule({
    Duration frequency = const Duration(days: 1),
    String? serverClientId,
  }) async {}

  @override
  Future<void> disconnect() async {}
}

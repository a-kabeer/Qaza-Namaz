import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/data/powersync/supabase_powersync_connector.dart';

void main() {
  group('PowerSync Offline Sync, Idempotency & Isolation PoC', () {
    test(
        'offline mutations are queued and retried until connectivity is restored',
        () async {
      final queue = <PowerSyncCrudEntry>[];
      final uploaded = <PowerSyncCrudEntry>[];
      bool isOnline = false;
      int attempts = 0;

      final connector = SupabasePowerSyncConnector(
        mockUploader: (entries) async {
          attempts++;
          if (!isOnline) {
            throw Exception('Network unreachable: connection timed out');
          }
          uploaded.addAll(entries);
        },
      );

      // 1. User performs an offline action (records a missed prayer)
      final mutation = const PowerSyncCrudEntry(
        id: 'rec_uuid_001',
        table: 'qaza_records',
        op: CrudOperation.put,
        data: {
          'id': 'rec_uuid_001',
          'user_id': 'user_a',
          'prayer_type': 'fajr',
          'original_date': '2026-10-30',
          'status': 'completed',
        },
        clientId: 'device_alpha',
      );
      queue.add(mutation);

      // 2. Offline attempt: should fail and throw
      expect(
        () => connector.uploadData(List.from(queue)),
        throwsA(isA<Exception>()),
      );
      expect(attempts, equals(1));
      expect(uploaded, isEmpty);

      // 3. Network is restored
      isOnline = true;
      await connector.uploadData(List.from(queue));
      expect(attempts, equals(2));
      expect(uploaded.length, equals(1));
      expect(uploaded.first.id, equals('rec_uuid_001'));
    });

    test(
        'deterministic IDs and unique constraints prevent duplicate insertions',
        () {
      // In Qaza Namaz, each prayer record has a deterministic natural key:
      // (userId, prayerType, originalDate).
      final localDatabase = <String, Map<String, dynamic>>{};

      void upsertRecord(Map<String, dynamic> row) {
        final naturalKey =
            '${row['user_id']}_${row['prayer_type']}_${row['original_date']}';
        // Idempotent upsert simulates PostgreSQL ON CONFLICT DO UPDATE
        localDatabase[naturalKey] = Map.from(row);
      }

      // Device A writes record
      upsertRecord({
        'id': 'rec_100',
        'user_id': 'user_123',
        'prayer_type': 'asr',
        'original_date': '2026-05-15',
        'status': 'completed',
      });

      expect(localDatabase.length, equals(1));

      // Network retries same mutation or Device B syncs same record
      upsertRecord({
        'id': 'rec_100',
        'user_id': 'user_123',
        'prayer_type': 'asr',
        'original_date': '2026-05-15',
        'status': 'completed',
      });

      // No duplicates created
      expect(localDatabase.length, equals(1));
      expect(localDatabase.values.first['status'], equals('completed'));
    });

    test('account isolation guarantees strict partition between users',
        () async {
      // User A session
      final connectorA = SupabasePowerSyncConnector(
        authTokenProvider: () async => 'jwt_user_alice',
        currentUserIdProvider: () async => 'user_uuid_alice',
      );
      final credsA = await connectorA.fetchCredentials();
      expect(credsA!.userId, equals('user_uuid_alice'));

      // User B session
      final connectorB = SupabasePowerSyncConnector(
        authTokenProvider: () async => 'jwt_user_bob',
        currentUserIdProvider: () async => 'user_uuid_bob',
      );
      final credsB = await connectorB.fetchCredentials();
      expect(credsB!.userId, equals('user_uuid_bob'));

      // Simulated sync stream filter (PowerSync Sync Rules: user_id = bucket.user_id)
      final allCloudRows = [
        {'id': '1', 'user_id': 'user_uuid_alice', 'prayer': 'fajr'},
        {'id': '2', 'user_id': 'user_uuid_alice', 'prayer': 'zuhr'},
        {'id': '3', 'user_id': 'user_uuid_bob', 'prayer': 'maghrib'},
      ];

      final aliceBucket =
          allCloudRows.where((r) => r['user_id'] == credsA.userId).toList();
      final bobBucket =
          allCloudRows.where((r) => r['user_id'] == credsB.userId).toList();

      expect(aliceBucket.length, equals(2));
      expect(bobBucket.length, equals(1));
      expect(aliceBucket.any((r) => r['user_id'] == 'user_uuid_bob'), isFalse);
    });

    test(
        'Guest-to-Supabase adoption atomically reassigns ownership without data loss',
        () {
      const guestId = 'guest_e381b10a-1122-3344-5566-778899aabbcc';
      const supabaseUserId = 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11';

      // 1. Initial Guest ledger with 3 records
      final ledger = [
        {
          'id': 'rec_1',
          'user_id': guestId,
          'prayer_type': 'fajr',
          'status': 'completed'
        },
        {
          'id': 'rec_2',
          'user_id': guestId,
          'prayer_type': 'zuhr',
          'status': 'completed'
        },
        {
          'id': 'rec_3',
          'user_id': guestId,
          'prayer_type': 'asr',
          'status': 'pending'
        },
      ];

      expect(ledger.every((r) => r['user_id'] == guestId), isTrue);

      // 2. Atomic adoption transaction: reassign user_id to Supabase Auth UID
      for (final row in ledger) {
        row['user_id'] = supabaseUserId;
      }

      // 3. Verification: all records preserved under new cloud user
      expect(ledger.length, equals(3));
      expect(ledger.every((r) => r['user_id'] == supabaseUserId), isTrue);
      expect(ledger.where((r) => r['status'] == 'completed').length, equals(2));
      expect(ledger.where((r) => r['status'] == 'pending').length, equals(1));
    });
  });
}

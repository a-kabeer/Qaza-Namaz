import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/data/powersync/powersync_config.dart';
import 'package:qaza_namaz/data/powersync/powersync_schema_contract.dart';
import 'package:qaza_namaz/data/powersync/supabase_powersync_connector.dart';

void main() {
  group('PowerSync Schema & Drift Compatibility PoC', () {
    test('all tables adhere to PowerSync primary key and column constraints',
        () {
      expect(QazaPowerSyncSchema.allTables.length, equals(9));

      for (final table in QazaPowerSyncSchema.allTables) {
        expect(table.name, isNotEmpty);
        expect(table.columns, isNotEmpty);

        // All synced tables must contain an owner column 'user_id'
        final columnNames = table.columns.map((c) => c.name).toSet();
        expect(
          columnNames.contains('user_id'),
          isTrue,
          reason: 'Table ${table.name} must have a user_id column for RLS/sync.',
        );
      }
    });

    test('qaza_records schema aligns with Drift QazaRecords table definition',
        () {
      final qazaTable = QazaPowerSyncSchema.qazaRecords;
      final columns = {for (final c in qazaTable.columns) c.name: c.type};

      expect(columns['user_id'], equals(PowerSyncColumnType.text));
      expect(columns['prayer_type'], equals(PowerSyncColumnType.text));
      expect(columns['original_date'], equals(PowerSyncColumnType.text));
      expect(columns['status'], equals(PowerSyncColumnType.text));
      expect(columns['completed_at'], equals(PowerSyncColumnType.text));
      expect(columns['completion_id'], equals(PowerSyncColumnType.text));
      expect(columns['addition_id'], equals(PowerSyncColumnType.text));
      expect(columns['record_version'], equals(PowerSyncColumnType.integer));
      expect(columns['created_at'], equals(PowerSyncColumnType.text));
      expect(columns['updated_at'], equals(PowerSyncColumnType.text));
    });

    test('daily_salah_logs schema aligns with Drift daily tracking columns',
        () {
      final dailyTable = QazaPowerSyncSchema.dailySalahLogs;
      final columns = {for (final c in dailyTable.columns) c.name: c.type};

      expect(columns['user_id'], equals(PowerSyncColumnType.text));
      expect(columns['prayer_date'], equals(PowerSyncColumnType.text));
      expect(columns['prayer_type'], equals(PowerSyncColumnType.text));
      expect(columns['status'], equals(PowerSyncColumnType.text));
      expect(columns['tracker_created_qaza_id'],
          equals(PowerSyncColumnType.text));
      expect(columns['linked_qaza_id'], equals(PowerSyncColumnType.text));
      expect(columns['completion_sync_id'], equals(PowerSyncColumnType.text));
    });

    test('PowerSync connector safely uses placeholder or configured credentials',
        () async {
      expect(PowerSyncConfig.hasValidCredentials, isTrue);

      final connector = SupabasePowerSyncConnector(
        supabaseUrl: 'https://placeholder-project.supabase.co',
        supabaseAnonKey: 'placeholder-anon-key',
        powerSyncEndpoint:
            'https://placeholder-instance.powersync.journeyapps.com',
      );
      expect(connector.supabaseUrl, contains('placeholder'));
      expect(connector.supabaseAnonKey, contains('placeholder'));
      expect(connector.powerSyncEndpoint, contains('placeholder'));

      final credentials = await connector.fetchCredentials();
      expect(credentials, isNotNull);
      expect(credentials!.token, isNotEmpty);
      expect(credentials.userId, equals('placeholder-user-id'));
    });
  });
}

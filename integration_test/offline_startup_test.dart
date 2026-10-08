import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/data_transfer/local_backup_service.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/data/local/drift_qaza_local_store.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/entities/user_profile.dart';
import 'package:qaza_namaz/features/prayer_time/data/offline_city_resolver.dart';
import 'package:qaza_namaz/features/prayer_time/domain/prayer_location.dart';
import 'package:qaza_namaz/features/prayer_time/domain/prayer_time_calculator.dart';
import 'package:qaza_namaz/features/prayer_time/domain/restricted_time.dart';
import 'package:qaza_namaz/features/prayer_time/domain/qibla_direction_service.dart';
import 'package:qaza_namaz/main.dart' as app;

QazaRecord _record(String id, DateTime date) => QazaRecord(
      id: id,
      userId: UserProfile.localLedgerUserId,
      prayerType: PrayerType.fajr,
      originalDate: date,
      createdAt: date,
      updatedAt: date,
    );

Future<void> _seedAccount(AppDatabase database) async {
  final now = DateTime(2026, 10, 8).microsecondsSinceEpoch;
  await database.customInsert(
    '''INSERT OR IGNORE INTO local_accounts
       (local_account_id, account_mode, lifecycle_state, created_at, updated_at)
       VALUES (?, 'local', 'active', ?, ?)''',
    variables: [
      Variable.withString(UserProfile.localLedgerUserId),
      Variable.withInt(now),
      Variable.withInt(now),
    ],
  );
  await database.customInsert(
    '''INSERT OR IGNORE INTO app_session_state
       (id, active_local_account_id)
       VALUES (1, ?)''',
    variables: [Variable.withString(UserProfile.localLedgerUserId)],
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'cold-start and complete offline functional matrix',
    (tester) async {
      await app.main();

      // Bounded pumps deliberately replace pumpAndSettle. Startup may expose an
      // indeterminate progress indicator while local initialization finishes.
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 5));

      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.textContaining('Qaza'), findsWidgets);

      // Core local Qaza lifecycle: create → page/sort → batch complete →
      // undo → delete → reset, including exact logical revision semantics.
      final database = AppDatabase(NativeDatabase.memory());
      try {
        final store = DriftQazaLocalStore(database: database);
        await _seedAccount(database);

        final records = List.generate(
          5,
          (index) => _record(
            'matrix-$index',
            DateTime(2026, 1, index + 1),
          ),
        );

        await store.appendRecords(UserProfile.localLedgerUserId, records);
        expect(await database.readDbRevision(), 2);

        final firstPage = await database.qazaRecordsDao.getKeysetPage(
          userId: UserProfile.localLedgerUserId,
          status: QazaStatus.pending.name,
          limit: 3,
        );
        expect(
          firstPage.records.map((record) => record.id).toList(),
          ['matrix-0', 'matrix-1', 'matrix-2'],
        );
        expect(firstPage.hasMore, isTrue);

        final secondPage = await database.qazaRecordsDao.getKeysetPage(
          userId: UserProfile.localLedgerUserId,
          status: QazaStatus.pending.name,
          limit: 3,
          afterOriginalDate: firstPage.nextOriginalDate,
          afterId: firstPage.nextId,
          afterPrayerType: firstPage.nextPrayerType?.name,
        );
        expect(
          secondPage.records.map((record) => record.id).toList(),
          ['matrix-3', 'matrix-4'],
        );
        expect(secondPage.hasMore, isFalse);

        final completed = await store.completeRecords(
          userId: UserProfile.localLedgerUserId,
          recordIds: records.map((record) => record.id).toList(),
          completedAt: DateTime(2026, 2, 1, 12),
        );
        expect(completed, hasLength(5));
        expect(await database.readDbRevision(), 3);

        final undone = await store.undoCompletions(
          userId: UserProfile.localLedgerUserId,
          expectedCompletionIds: {
            completed.first.id: completed.first.completionId!,
          },
          undoneAt: DateTime(2026, 2, 1, 13),
        );
        expect(undone.single.status, QazaStatus.pending);
        expect(await database.readDbRevision(), 4);

        expect(
          await store.deleteRecord(
            userId: UserProfile.localLedgerUserId,
            recordId: records.last.id,
          ),
          isTrue,
        );
        expect(await database.readDbRevision(), 5);

        await store.retireUserData(
          userId: UserProfile.localLedgerUserId,
        );
        expect(await database.readDbRevision(), 6);
        expect(
          await database.qazaRecordsDao.getAll(
            userId: UserProfile.localLedgerUserId,
          ),
          isEmpty,
        );
        await store.retireUserData(
          userId: UserProfile.localLedgerUserId,
        );
        expect(await database.readDbRevision(), 6);

        // Portable backup/restore remains entirely local and preserves the
        // receiving installation's device identity.
        final source = AppDatabase(NativeDatabase.memory());
        try {
          await _seedAccount(source);
          await source.qazaRecordsDao.insertRecord(
            QazaRecordsCompanion.insert(
              id: 'backup-record',
              userId: UserProfile.localLedgerUserId,
              prayerType: PrayerType.fajr.name,
              originalDate: DateTime(2026, 3, 1),
              status: QazaStatus.pending.name,
              createdAt: DateTime(2026, 3, 1),
              updatedAt: DateTime(2026, 3, 1),
            ),
          );
          final backup = await LocalBackupService(source).exportJson();

          final receiving = AppDatabase(NativeDatabase.memory());
          try {
            await receiving.customInsert(
              '''INSERT OR REPLACE INTO device_metadata
                 (id, device_instance_id) VALUES (1, ?)''',
              variables: [Variable.withString('receiving-device')],
            );

            final restored =
                await LocalBackupService(receiving).importJson(backup);
            expect(restored.recordCount, 1);
            expect(restored.dbRevision, 2);

            final device = await receiving.customSelect(
              'SELECT device_instance_id FROM device_metadata WHERE id = 1',
            ).get();
            expect(
              device.single.read<String>('device_instance_id'),
              'receiving-device',
            );
          } finally {
            await receiving.close();
          }
        } finally {
          await source.close();
        }
      } finally {
        await database.close();
      }

      // Offline prayer-time capability: no network service is used for city
      // lookup, astronomical calculation, restricted-time windows, or Qibla.
      tzdata.initializeTimeZones();
      final catalog = OfflineCityCatalog();
      await catalog.load();
      expect(
        catalog.citiesForCountry('PK', query: 'Karachi'),
        isNotEmpty,
      );

      final location = PrayerLocation(
        latitude: 24.8607,
        longitude: 67.0011,
        city: 'Karachi',
        region: 'Sindh',
        country: 'Pakistan',
        countryCode: 'PK',
        timezoneId: 'Asia/Karachi',
        source: PrayerLocationSource.city,
      );
      final schedule = const PrayerTimeCalculator().calculate(
        location: location,
        madhab: Madhab.hanafi,
        localDate: DateTime(2026, 10, 8),
      );
      expect(schedule.timesUtc.values.every((value) => value.isUtc), isTrue);

      final zone = tz.getLocation('Asia/Karachi');
      final windows = const RestrictedTimeCalculator().forSchedule(
        schedule,
        zone,
      );
      expect(windows, hasLength(3));

      const qibla = QiblaDirectionService();
      final bearing = qibla.calculateBearing(
        latitude: location.latitude,
        longitude: location.longitude,
      );
      expect(bearing, inInclusiveRange(0, 360));
      expect(
        qibla.relativeQiblaAngle(
          qiblaBearing: bearing,
          trueHeading: bearing,
        ),
        closeTo(0, 0.000001),
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/data/powersync/guest_data_adoption_service.dart';
import 'package:qaza_namaz/domain/entities/local_account.dart';
import 'package:qaza_namaz/features/account/adoption_conflict_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late GuestDataAdoptionService service;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    service = GuestDataAdoptionService(database: db);
  });

  tearDown(() async {
    await db.close();
  });

  group('GuestDataAdoptionService Tests', () {
    test('accurately counts guest records and evaluates auto-adoption',
        () async {
      const guestId = 'guest_123';
      const cloudUserId = 'user_abc';

      // Insert 2 records for guest
      await db.into(db.qazaRecords).insert(
            QazaRecordsCompanion.insert(
              id: 'rec_1',
              userId: guestId,
              prayerType: 'fajr',
              originalDate: DateTime(2025, 1, 1),
              status: 'pending',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
      await db.into(db.qazaRecords).insert(
            QazaRecordsCompanion.insert(
              id: 'rec_2',
              userId: guestId,
              prayerType: 'zuhr',
              originalDate: DateTime(2025, 1, 1),
              status: 'completed',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      final count = await service.countGuestRecords(guestId);
      expect(count, equals(2));

      // Without cloud client, cloud count is 0 -> canAutoAdopt is true
      final eval = await service.evaluate(
        guestWorkspaceId: guestId,
        supabaseUserId: cloudUserId,
      );
      expect(eval.hasGuestData, isTrue);
      expect(eval.hasCloudData, isFalse);
      expect(eval.canAutoAdopt, isTrue);
      expect(eval.requiresResolution, isFalse);
    });

    test('reassigns guest records to supabase user on keepBoth', () async {
      const guestId = 'guest_reassign';
      const cloudUserId = 'user_target';

      await db.into(db.qazaRecords).insert(
            QazaRecordsCompanion.insert(
              id: 'rec_adopt_1',
              userId: guestId,
              prayerType: 'asr',
              originalDate: DateTime(2025, 2, 1),
              status: 'pending',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      await service.executeAdoption(
        guestWorkspaceId: guestId,
        supabaseUserId: cloudUserId,
        resolution: AdoptionResolution.keepBoth,
      );

      final guestCountAfter = await service.countGuestRecords(guestId);
      expect(guestCountAfter, equals(0));

      final targetRecords = await (db.select(db.qazaRecords)
            ..where((tbl) =>
                tbl.userId.equals(supabaseLocalWorkspaceId(cloudUserId))))
          .get();
      expect(targetRecords.length, equals(1));
      expect(targetRecords.first.id, equals('rec_adopt_1'));
    });

    test('purges local guest records on keepCloud', () async {
      const guestId = 'guest_purge';
      const cloudUserId = 'user_target_2';

      await db.into(db.qazaRecords).insert(
            QazaRecordsCompanion.insert(
              id: 'rec_purge_1',
              userId: guestId,
              prayerType: 'maghrib',
              originalDate: DateTime(2025, 3, 1),
              status: 'pending',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      await service.executeAdoption(
        guestWorkspaceId: guestId,
        supabaseUserId: cloudUserId,
        resolution: AdoptionResolution.keepCloud,
      );

      final guestCountAfter = await service.countGuestRecords(guestId);
      expect(guestCountAfter, equals(0));

      final targetRecords = await (db.select(db.qazaRecords)
            ..where((tbl) =>
                tbl.userId.equals(supabaseLocalWorkspaceId(cloudUserId))))
          .get();
      expect(targetRecords, isEmpty);
    });
  });

  group('AdoptionConflictDialog Widget Tests', () {
    testWidgets('dialog renders and returns selected resolution',
        (tester) async {
      AdoptionResolution? chosen;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                chosen = await AdoptionConflictDialog.show(
                  context,
                  guestCount: 15,
                  cloudCount: 120,
                );
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Existing Cloud Data Found'), findsOneWidget);
      expect(find.textContaining('15 local Guest prayers'), findsOneWidget);
      expect(find.textContaining('120 recorded prayers'), findsOneWidget);

      final keepBothTile =
          find.byKey(const Key('adoption_resolution_keep_both'));
      expect(keepBothTile, findsOneWidget);

      await tester.tap(keepBothTile);
      await tester.pumpAndSettle();

      expect(chosen, equals(AdoptionResolution.keepBoth));
    });
  });
}

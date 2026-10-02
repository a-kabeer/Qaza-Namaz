import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/data/local/database/tables/qaza_records.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';

QazaRecordsCompanion _pendingRow({
  required String id,
  required PrayerType prayerType,
  required DateTime originalDate,
}) {
  return QazaRecordsCompanion.insert(
    id: id,
    userId: 'local',
    prayerType: prayerType.name,
    originalDate: originalDate,
    status: QazaStatus.pending.name,
    createdAt: originalDate,
    updatedAt: originalDate,
  );
}

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'Pending keyset pagination advances with originalDate/prayer/id cursor',
    () async {
      final sameDay = DateTime(2026, 9, 10);
      await database.qazaRecordsDao.insertRecords([
        _pendingRow(
          id: 'a',
          prayerType: PrayerType.fajr,
          originalDate: sameDay,
        ),
        _pendingRow(
          id: 'b',
          prayerType: PrayerType.zuhr,
          originalDate: sameDay,
        ),
        _pendingRow(
          id: 'c',
          prayerType: PrayerType.fajr,
          originalDate: DateTime(2026, 9, 11),
        ),
        _pendingRow(
          id: 'd',
          prayerType: PrayerType.zuhr,
          originalDate: DateTime(2026, 9, 12),
        ),
        _pendingRow(
          id: 'e',
          prayerType: PrayerType.fajr,
          originalDate: DateTime(2026, 9, 13),
        ),
      ]);

      final first = await database.qazaRecordsDao.getKeysetPage(
        userId: 'local',
        status: QazaStatus.pending.name,
        limit: 2,
      );

      expect(first.records.map((record) => record.id), ['a', 'b']);
      expect(first.hasMore, isTrue);

      final second = await database.qazaRecordsDao.getKeysetPage(
        userId: 'local',
        status: QazaStatus.pending.name,
        limit: 2,
        afterOriginalDate: first.records.last.originalDate,
        afterPrayerType: first.records.last.prayerType.name,
        afterId: first.records.last.id,
      );

      expect(second.records.map((record) => record.id), ['c', 'd']);
      expect(
        second.records.map((record) => record.id).toSet().intersection(
              first.records.map((record) => record.id).toSet(),
            ),
        isEmpty,
      );
      expect(second.hasMore, isTrue);

      final third = await database.qazaRecordsDao.getKeysetPage(
        userId: 'local',
        status: QazaStatus.pending.name,
        limit: 2,
        afterOriginalDate: second.records.last.originalDate,
        afterPrayerType: second.records.last.prayerType.name,
        afterId: second.records.last.id,
      );

      expect(third.records.map((record) => record.id), ['e']);
      expect(third.hasMore, isFalse);
    },
  );

  test('Pending keyset cursor requires the date/prayer/id triple',
      () async {
    await expectLater(
      database.qazaRecordsDao.getKeysetPage(
        userId: 'local',
        status: QazaStatus.pending.name,
        afterOriginalDate: DateTime(2026, 9, 10),
        afterId: 'a',
      ),
      throwsArgumentError,
    );

    await expectLater(
      database.qazaRecordsDao.getKeysetPage(
        userId: 'local',
        status: QazaStatus.pending.name,
        afterOriginalDate: DateTime(2026, 9, 10),
        afterPrayerType: PrayerType.fajr.name,
      ),
      throwsArgumentError,
    );

    await expectLater(
      database.qazaRecordsDao.getKeysetPage(
        userId: 'local',
        status: QazaStatus.pending.name,
        afterPrayerType: PrayerType.fajr.name,
        afterId: 'a',
      ),
      throwsArgumentError,
    );
  });
}

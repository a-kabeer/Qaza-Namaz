import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/local/qaza_local_store.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/services/guest_migration_service.dart';

import 'support/in_memory_qaza_repository.dart';

const guestId = 'guest';
const accountId = 'account';
final stamp = DateTime(2026, 9, 18, 12);

class FakeLocalStore extends QazaLocalStore {
  final recordsByUser = <String, List<QazaRecord>>{};
  final outboxByUser = <String, List<PendingSyncOp>>{};
  bool failNextOutboxSave = false;

  @override
  Future<OfflineCacheSnapshot> load() async => OfflineCacheSnapshot(
        recordsByUser: {
          for (final entry in recordsByUser.entries)
            entry.key: List<QazaRecord>.of(entry.value),
        },
        outboxByUser: {
          for (final entry in outboxByUser.entries)
            entry.key: List<PendingSyncOp>.of(entry.value),
        },
      );

  @override
  Future<void> saveRecords(
      String userId, List<QazaRecord> records) async {
    recordsByUser[userId] = List<QazaRecord>.of(records);
  }

  @override
  Future<void> saveOutbox(
      String userId, List<PendingSyncOp> ops) async {
    if (failNextOutboxSave) {
      failNextOutboxSave = false;
      throw StateError('simulated outbox write failure');
    }
    outboxByUser[userId] = List<PendingSyncOp>.of(ops);
  }

  @override
  Future<void> saveRecordsAndOutbox(
    String userId,
    List<QazaRecord> records,
    List<PendingSyncOp> ops,
  ) async {
    if (failNextOutboxSave) {
      failNextOutboxSave = false;
      throw StateError('simulated atomic write failure');
    }
    recordsByUser[userId] = List<QazaRecord>.of(records);
    outboxByUser[userId] = List<PendingSyncOp>.of(ops);
  }

  @override
  Future<void> saveLastSync(String userId, DateTime? lastSync) async {}

  @override
  Future<void> retireUserData({required String userId}) async {
    recordsByUser.remove(userId);
    outboxByUser.remove(userId);
  }
}

QazaRecord record(
  String userId,
  PrayerType prayer,
  String date, {
  QazaStatus status = QazaStatus.pending,
  DateTime? completedAt,
}) {
  final originalDate = DateTime.parse(date);
  return QazaRecord(
    id: userId + '_' + prayer.name + '_' + date,
    userId: userId,
    prayerType: prayer,
    originalDate: originalDate,
    status: status,
    completedAt: completedAt,
    createdAt: stamp,
    updatedAt: completedAt ?? stamp,
  );
}

void main() {
  late FakeLocalStore local;
  late InMemoryQazaRepository remote;
  late GuestMigrationService service;

  setUp(() {
    local = FakeLocalStore();
    remote = InMemoryQazaRepository();
    service = GuestMigrationService(
      localStore: local,
      remoteRepository: remote,
    );
  });

  test('empty guest ledger is detected without touching account data',
      () async {
    await remote.addRecord(record(accountId, PrayerType.fajr, '2026-01-01'));

    expect(await service.hasGuestData(guestUserId: guestId), isFalse);
    final result = await service.migrate(
      guestUserId: guestId,
      accountUserId: accountId,
      completedAt: stamp,
    );

    expect(result.movedAnything, isFalse);
    expect(await remote.getRecords(userId: accountId), hasLength(1));
    expect(local.recordsByUser[guestId], isNull);
  });

  test('merge deduplicates pending + pending by prayer/date', () async {
    local.recordsByUser[guestId] = [
      record(guestId, PrayerType.fajr, '2026-01-02'),
    ];
    local.recordsByUser[accountId] = [
      record(accountId, PrayerType.fajr, '2026-01-02'),
    ];

    final result = await service.migrate(
      guestUserId: guestId,
      accountUserId: accountId,
      completedAt: stamp,
    );

    expect(result.added, 0);
    expect(local.recordsByUser[accountId], hasLength(1));
    expect(local.recordsByUser[accountId]!.single.status, QazaStatus.pending);
  });


  test('deduplication uses normalized original calendar date', () async {
    local.recordsByUser[guestId] = [
      record(guestId, PrayerType.fajr, '2026-02-10'),
    ];
    local.recordsByUser[guestId]!.first.copyWith(
      originalDate: DateTime(2026, 2, 10, 23, 45),
    );

    local.recordsByUser[accountId] = [
      record(accountId, PrayerType.fajr, '2026-02-10'),
    ];

    await service.migrate(
      guestUserId: guestId,
      accountUserId: accountId,
      completedAt: stamp,
    );

    expect(local.recordsByUser[accountId], hasLength(1));
  });

  test('completed guest wins over pending account and stays completed',
      () async {
    local.recordsByUser[guestId] = [
      record(
        guestId,
        PrayerType.fajr,
        '2026-01-03',
        status: QazaStatus.completed,
        completedAt: stamp,
      ),
    ];
    local.recordsByUser[accountId] = [
      record(accountId, PrayerType.fajr, '2026-01-03'),
    ];

    await service.migrate(
      guestUserId: guestId,
      accountUserId: accountId,
      completedAt: stamp,
    );

    final rows = local.recordsByUser[accountId]!;
    expect(rows, hasLength(1));
    expect(rows.single.status, QazaStatus.completed);
    expect(rows.single.userId, accountId);
    expect(local.outboxByUser[accountId]!.single.type, SyncOpType.add);
    expect(local.outboxByUser[accountId]!.single.record!.status,
        QazaStatus.completed);
  });

  test('pending guest never downgrades a completed account record', () async {
    await remote.addRecord(
      record(
        accountId,
        PrayerType.fajr,
        '2026-01-04',
        status: QazaStatus.completed,
        completedAt: stamp,
      ),
    );
    local.recordsByUser[guestId] = [
      record(guestId, PrayerType.fajr, '2026-01-04'),
    ];

    await service.migrate(
      guestUserId: guestId,
      accountUserId: accountId,
      completedAt: stamp,
    );

    expect(local.recordsByUser[accountId]!.single.status,
        QazaStatus.completed);
    expect(local.outboxByUser[accountId], isEmpty);
  });

  test('remote pending + completed guest queues completion on remote ID',
      () async {
    final remoteRecord = record(accountId, PrayerType.zuhr, '2026-01-05');
    await remote.addRecord(remoteRecord);
    local.recordsByUser[guestId] = [
      record(
        guestId,
        PrayerType.zuhr,
        '2026-01-05',
        status: QazaStatus.completed,
        completedAt: stamp,
      ),
    ];

    await service.migrate(
      guestUserId: guestId,
      accountUserId: accountId,
      completedAt: stamp,
    );

    final accountLocal = local.recordsByUser[accountId]!;
    expect(accountLocal, hasLength(1));
    expect(accountLocal.single.status, QazaStatus.completed);

    final completionOps = local.outboxByUser[accountId]!
        .where((op) => op.type == SyncOpType.complete)
        .toList();
    expect(completionOps, hasLength(1));
    expect(completionOps.single.targetRecordId, remoteRecord.id);
  });

  test('same completed records collapse to one record', () async {
    local.recordsByUser[guestId] = [
      record(
        guestId,
        PrayerType.asr,
        '2026-01-06',
        status: QazaStatus.completed,
        completedAt: stamp,
      ),
    ];
    local.recordsByUser[accountId] = [
      record(
        accountId,
        PrayerType.asr,
        '2026-01-06',
        status: QazaStatus.completed,
        completedAt: stamp,
      ),
    ];
    await remote.addRecord(
      record(
        accountId,
        PrayerType.asr,
        '2026-01-06',
        status: QazaStatus.completed,
        completedAt: stamp,
      ),
    );

    await service.migrate(
      guestUserId: guestId,
      accountUserId: accountId,
      completedAt: stamp,
    );

    expect(local.recordsByUser[accountId], hasLength(1));
    expect(
      local.outboxByUser[accountId]!.where(
        (op) => op.type == SyncOpType.complete,
      ),
      isEmpty,
    );
  });

  test('repeated migration is idempotent and does not duplicate outbox work',
      () async {
    local.recordsByUser[guestId] = [
      record(guestId, PrayerType.maghrib, '2026-01-07'),
      record(
        guestId,
        PrayerType.isha,
        '2026-01-08',
        status: QazaStatus.completed,
        completedAt: stamp,
      ),
    ];

    await service.migrate(
      guestUserId: guestId,
      accountUserId: accountId,
      completedAt: stamp,
    );
    final firstOutbox =
        List<PendingSyncOp>.of(local.outboxByUser[accountId]!);

    await service.migrate(
      guestUserId: guestId,
      accountUserId: accountId,
      completedAt: stamp,
    );

    expect(local.recordsByUser[accountId], hasLength(2));
    expect(local.outboxByUser[accountId], hasLength(2));
    expect(
      local.outboxByUser[accountId]!.map((op) => op.id).toSet(),
      hasLength(2),
    );
    expect(
      firstOutbox.map((op) => op.id).toSet(),
      equals(local.outboxByUser[accountId]!.map((op) => op.id).toSet()),
    );
  });

  test('failed migration leaves guest data intact and can be retried',
      () async {
    local.recordsByUser[guestId] = [
      record(guestId, PrayerType.witr, '2026-01-09'),
    ];
    local.failNextOutboxSave = true;

    expect(
      () => service.migrate(
        guestUserId: guestId,
        accountUserId: accountId,
        completedAt: stamp,
      ),
      throwsStateError,
    );

    expect(local.recordsByUser[guestId], hasLength(1));
    expect(local.recordsByUser[accountId], isNull);

    final retry = await service.migrate(
      guestUserId: guestId,
      accountUserId: accountId,
      completedAt: stamp,
    );

    expect(retry.added, 0);
    expect(local.recordsByUser[accountId], hasLength(1));
    expect(local.outboxByUser[accountId], hasLength(1));

    await service.retireGuestData(guestUserId: guestId);
    expect(local.recordsByUser[guestId], isNull);
  });
}

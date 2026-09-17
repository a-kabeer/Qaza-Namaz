import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/data/repositories/drift_qaza_repository.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';

void main() {
  late AppDatabase db;
  late DriftQazaRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = DriftQazaRepository(db);
  });

  tearDown(() => db.close());

  QazaRecord record({
    String id = 'record-1',
    String userId = 'user-a',
    PrayerType prayer = PrayerType.fajr,
    DateTime? date,
  }) {
    final value = date ?? DateTime(2026, 1, 1);
    return QazaRecord(
      id: id,
      userId: userId,
      prayerType: prayer,
      originalDate: value,
      status: QazaStatus.pending,
      createdAt: value,
      updatedAt: value,
    );
  }

  test('duplicate add does not overwrite an existing Qaza record', () async {
    final original = record();
    await repository.addRecord(original);

    final duplicate = original.copyWith(
      status: QazaStatus.completed,
      completedAt: DateTime(2026, 2, 1),
      updatedAt: DateTime(2026, 2, 1),
    );
    await repository.addRecord(duplicate);

    final stored = await repository.getRecords(userId: 'user-a');
    expect(stored, hasLength(1));
    expect(stored.single.status, QazaStatus.pending);
    expect(stored.single.completedAt, isNull);
  });

  test('duplicate date/prayer add with a different id is rejected by the unique key', () async {
    await repository.addRecord(record(id: 'first'));
    await repository.addRecord(record(id: 'second'));

    final stored = await repository.getRecords(userId: 'user-a');
    expect(stored, hasLength(1));
    expect(stored.single.id, 'first');
  });

  test('batch mutation is scoped to one user', () async {
    expect(
      () => repository.addRecords([
        record(id: 'a', userId: 'user-a'),
        record(id: 'b', userId: 'user-b'),
      ]),
      throwsStateError,
    );
  });

  test('repeated completion is idempotent and keeps the earliest completion time', () async {
    await repository.addRecord(record());
    final firstCompletion = DateTime(2026, 2, 2);
    final laterCompletion = DateTime(2026, 2, 3);

    await repository.completeRecord(
      userId: 'user-a',
      recordId: 'record-1',
      completedAt: firstCompletion,
    );
    await repository.completeRecord(
      userId: 'user-a',
      recordId: 'record-1',
      completedAt: laterCompletion,
    );

    final stored = await repository.getRecords(userId: 'user-a');
    expect(stored.single.status, QazaStatus.completed);
    expect(stored.single.completedAt, firstCompletion);
  });

  test('completion cannot mutate another user record', () async {
    await repository.addRecord(record());

    await repository.completeRecord(
      userId: 'user-b',
      recordId: 'record-1',
      completedAt: DateTime(2026, 2, 1),
    );

    final stored = await repository.getRecords(userId: 'user-a');
    expect(stored.single.status, QazaStatus.pending);
  });
}

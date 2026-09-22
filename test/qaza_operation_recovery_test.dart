import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/qaza_operation.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/services/qaza_operation_service.dart';
import 'package:qaza_namaz/domain/services/qaza_service.dart';
import 'package:qaza_namaz/domain/repositories/qaza_operation_repository.dart';
import 'support/in_memory_qaza_repository.dart';

class _FakeOperationRepository implements QazaOperationRepository {
  final Map<String, QazaOperation> values = {};
  @override
  Future<void> save(QazaOperation operation) async => values[operation.operationId] = operation;
  @override
  Future<QazaOperation?> get(String userId, String operationId) async => values[operationId];
  @override
  Future<List<QazaOperation>> listRecent(String userId, {int limit = 50}) async => values.values.where((v) => v.userId == userId).toList();
  @override
  Future<void> delete(String userId, String operationId) async => values.remove(operationId);
}

void main() {
  test('one operation groups an import and safe undo preserves changed rows', () async {
    final repository = InMemoryQazaRepository();
    final opRepo = _FakeOperationRepository();
    final clock = DateTime(2026, 1, 1, 12);
    final operationService = QazaOperationService(opRepo, now: () => clock);
    final qazaService = QazaService(repository, prayerTimeBlockedResolver: ({required userId, required dates, required prayerTypes}) async => const {});
    final operation = await operationService.begin(userId: 'test-user', type: QazaOperationType.calculatorImport);

    final added = await qazaService.recordQazaForDates(
      userId: 'test-user',
      dates: [DateTime(2025, 1, 1)],
      prayerTypes: [PrayerType.fajr, PrayerType.zuhr, PrayerType.asr],
      operationId: operation.operationId,
      operationCreatedAt: operation.createdAt,
    );
    await operationService.finish(operation, status: QazaOperationStatus.completed, affectedRecordCount: added);
    expect(added, 3);
    expect(opRepo.values.values.single.recordCount, 3);

    final pending = await repository.getRecords(userId: 'test-user', status: QazaStatus.pending);
    await repository.updateRecord(record: pending[0].copyWith(updatedAt: clock.add(const Duration(minutes: 1))));
    await repository.completeRecord(userId: 'test-user', recordId: pending[1].id, completedAt: clock.add(const Duration(minutes: 2)));

    final removed = await qazaService.undoAddedOperation(
      userId: 'test-user',
      operationId: operation.operationId,
      expectedCreatedAt: operation.createdAt,
    );
    expect(removed, 1);

    final remaining = await repository.getRecords(userId: 'test-user');
    expect(remaining, hasLength(2));
    expect(remaining.any((r) => r.status == QazaStatus.completed), isTrue);

    await operationService.finish(operation, status: QazaOperationStatus.partial, affectedRecordCount: removed);
    expect(opRepo.values.values.single.recordCount, 3);
    expect(opRepo.values.values.single.affectedRecordCount, 1);
  });

  test('soft delete is recoverable and excluded from normal reads', () async {
    final repository = InMemoryQazaRepository();
    final a = QazaRecord(
      id: 'a', userId: 'test-user', prayerType: PrayerType.fajr, originalDate: DateTime(2025, 1, 1),
      status: QazaStatus.pending, createdAt: DateTime(2026), updatedAt: DateTime(2026),
    );
    final b = a.copyWith(id: 'b', prayerType: PrayerType.zuhr, originalDate: DateTime(2025, 1, 2));
    await repository.addRecords([a, b]);
    final at = DateTime(2026, 2);
    expect(await repository.softDeleteRecords(userId: 'test-user', recordIds: ['a', 'b'], deletedAt: at, operationId: 'op'), 2);
    expect(await repository.getRecords(userId: 'test-user'), isEmpty);
    expect((await repository.getRecentlyDeletedPage(userId: 'test-user')).records, hasLength(2));
    expect(await repository.restoreDeletedRecords(userId: 'test-user', recordIds: ['a'], restoredAt: at.add(const Duration(minutes: 1)), operationId: 'restore'), 1);
    expect((await repository.getRecords(userId: 'test-user')).map((r) => r.id), contains('a'));
    expect((await repository.getRecentlyDeletedPage(userId: 'test-user')).records.map((r) => r.id), contains('b'));
  });
}

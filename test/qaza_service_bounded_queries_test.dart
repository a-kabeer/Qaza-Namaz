import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/services/qaza_service.dart';
import 'support/in_memory_qaza_repository.dart';

class _TrackingRepository extends InMemoryQazaRepository {
  int fullLedgerReads = 0;
  int boundedDateReads = 0;
  int lastBoundedDateCount = 0;

  @override
  Future<List<QazaRecord>> getRecords({
    required String userId,
    PrayerType? prayerType,
    QazaStatus? status,
  }) async {
    fullLedgerReads++;
    return super.getRecords(
      userId: userId,
      prayerType: prayerType,
      status: status,
    );
  }

  @override
  Future<List<QazaRecord>> getRecordsForDates({
    required String userId,
    required Iterable<DateTime> dates,
  }) async {
    boundedDateReads++;
    final requested = dates.toList(growable: false);
    lastBoundedDateCount = requested.length;
    final all = await super.getRecords(userId: userId);
    return all.where((record) {
      return requested.any((date) =>
          record.originalDate.year == date.year &&
          record.originalDate.month == date.month &&
          record.originalDate.day == date.day);
    }).toList(growable: false);
  }
}

void main() {
  test('availability uses bounded date query instead of full ledger', () async {
    final repository = _TrackingRepository();
    final service = QazaService(repository);

    final start = DateTime(2020, 1, 1);
    final dates = [for (var i = 0; i < 10000; i++) start.add(Duration(days: i))];

    final analysis = await service.analyzeAvailability(
      userId: 'u1',
      dates: dates,
      prayerTypes: PrayerType.values,
    );

    expect(analysis.total, 60000);
    expect(analysis.newCount, 60000);
    expect(repository.boundedDateReads, 1);
    expect(repository.lastBoundedDateCount, 10000);
    expect(repository.fullLedgerReads, 0);
  });
}

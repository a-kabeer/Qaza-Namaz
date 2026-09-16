import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/repositories/qaza_repository.dart';
import 'support/in_memory_qaza_repository.dart';

QazaRecord _record(String id, PrayerType prayer, QazaStatus status, {String userId = 'u1'}) => QazaRecord(
      id: id,
      userId: userId,
      prayerType: prayer,
      originalDate: DateTime(2026, 9, 1),
      status: status,
      completedAt: status == QazaStatus.completed ? DateTime(2026, 9, 2) : null,
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 1),
    );

void main() {
  test('summary returns totals and every prayer bucket', () async {
    final repository = InMemoryQazaRepository();
    await repository.addRecords([
      _record('fajr-1', PrayerType.fajr, QazaStatus.pending),
      _record('fajr-2', PrayerType.fajr, QazaStatus.completed),
      _record('isha-1', PrayerType.isha, QazaStatus.pending),
      _record('witr-1', PrayerType.witr, QazaStatus.completed),
    ]);

    final summary = await repository.getSummary('u1');

    expect(summary.total, 4);
    expect(summary.pending, 2);
    expect(summary.completed, 2);
    expect(summary.byPrayer[PrayerType.fajr]!.pending, 1);
    expect(summary.byPrayer[PrayerType.fajr]!.completed, 1);
    expect(summary.byPrayer[PrayerType.isha]!.pending, 1);
    expect(summary.byPrayer[PrayerType.witr]!.completed, 1);
    expect(summary.byPrayer[PrayerType.maghrib]!.pending, 0);
    expect(summary.byPrayer[PrayerType.maghrib]!.completed, 0);
  });

  test('summary is isolated by user', () async {
    final repository = InMemoryQazaRepository();
    await repository.addRecords([
      _record('u1-fajr', PrayerType.fajr, QazaStatus.pending),
      _record('u2-isha', PrayerType.isha, QazaStatus.completed, userId: 'u2'),
    ]);

    final u1 = await repository.getSummary('u1');
    final u2 = await repository.getSummary('u2');

    expect(u1.total, 1);
    expect(u1.byPrayer[PrayerType.fajr]!.pending, 1);
    expect(u2.total, 1);
    expect(u2.byPrayer[PrayerType.isha]!.completed, 1);
  });
}

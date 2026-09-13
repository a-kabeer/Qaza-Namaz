import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/repositories/in_memory_qaza_repository.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/services/qaza_service.dart';
import 'package:qaza_namaz/features/qaza/qaza_completion_flow_v2.dart';

QazaRecord record({
  required String id,
  required PrayerType prayer,
  required DateTime originalDate,
  QazaStatus status = QazaStatus.pending,
  DateTime? completedAt,
}) {
  final now = DateTime(2026, 9, 14, 10);
  return QazaRecord(
    id: id,
    userId: 'test-user',
    prayerType: prayer,
    originalDate: originalDate,
    status: status,
    completedAt: completedAt,
    createdAt: now,
    updatedAt: now,
  );
}

Future<void> pumpComplete(WidgetTester tester, InMemoryQazaRepository repository) async {
  await tester.pumpWidget(
    MaterialApp(
      home: CompleteQazaV2Screen(
        userId: 'test-user',
        service: QazaService(repository),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> pumpNamazWise(WidgetTester tester, InMemoryQazaRepository repository) async {
  await tester.pumpWidget(
    MaterialApp(
      home: NamazWiseV2Screen(
        userId: 'test-user',
        service: QazaService(repository),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Complete flow presents oldest pending Fajr record', (tester) async {
    final repository = InMemoryQazaRepository();
    await repository.addRecords([
      record(id: 'fajr_new', prayer: PrayerType.fajr, originalDate: DateTime(2026, 9, 10)),
      record(id: 'fajr_old', prayer: PrayerType.fajr, originalDate: DateTime(2026, 9, 2)),
    ]);

    await pumpComplete(tester, repository);

    expect(find.text('Oldest pending record'), findsOneWidget);
    expect(find.text('02 Sep 2026'), findsOneWidget);
    expect(find.text('Complete oldest pending'), findsOneWidget);
  });

  testWidgets('Completing oldest pending preserves original date and reduces pending records', (tester) async {
    final repository = InMemoryQazaRepository();
    await repository.addRecords([
      record(id: 'fajr_old', prayer: PrayerType.fajr, originalDate: DateTime(2026, 9, 2)),
      record(id: 'fajr_new', prayer: PrayerType.fajr, originalDate: DateTime(2026, 9, 10)),
    ]);

    await pumpComplete(tester, repository);
    await tester.tap(find.text('Complete oldest pending'));
    await tester.pumpAndSettle();

    final records = await repository.getRecords(userId: 'test-user');
    final completed = records.singleWhere((r) => r.id == 'fajr_old');
    final pending = records.where((r) => r.status == QazaStatus.pending).toList();

    expect(completed.status, QazaStatus.completed);
    expect(completed.originalDate, DateTime(2026, 9, 2));
    expect(completed.completedAt, isNotNull);
    expect(pending.map((r) => r.id), contains('fajr_new'));
  });

  testWidgets('Namaz-wise flow offers all six prayers and opens Witr pending-date selection', (tester) async {
    final repository = InMemoryQazaRepository();
    await repository.addRecords([
      record(id: 'witr_pending', prayer: PrayerType.witr, originalDate: DateTime(2026, 8, 20)),
    ]);

    await pumpNamazWise(tester, repository);

    for (final prayer in PrayerType.values) {
      expect(find.text(prayer.label), findsOneWidget);
    }

    final witr = find.text('Witr');
    await tester.ensureVisible(witr);
    await tester.tap(witr);
    await tester.pumpAndSettle();

    expect(find.text('Witr Qaza'), findsOneWidget);
    expect(find.text('20 Aug 2026'), findsOneWidget);
    expect(find.text('Complete 0 selected'), findsOneWidget);
  });

  testWidgets('Namaz-wise flow supports multi-select completion for one prayer', (tester) async {
    final repository = InMemoryQazaRepository();
    await repository.addRecords([
      record(id: 'witr_1', prayer: PrayerType.witr, originalDate: DateTime(2026, 8, 20)),
      record(id: 'witr_2', prayer: PrayerType.witr, originalDate: DateTime(2026, 8, 21)),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: PendingDatesV2Screen(
          userId: 'test-user',
          service: QazaService(repository),
          prayer: PrayerType.witr,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final boxes = find.byType(CheckboxListTile);
    expect(boxes, findsNWidgets(2));
    await tester.ensureVisible(boxes.at(0));
    await tester.tap(boxes.at(0));
    await tester.ensureVisible(boxes.at(1));
    await tester.tap(boxes.at(1));
    await tester.pumpAndSettle();

    expect(find.text('Complete 2 selected'), findsOneWidget);
    await tester.ensureVisible(find.text('Complete 2 selected'));
    await tester.tap(find.text('Complete 2 selected'));
    await tester.pumpAndSettle();

    final records = await repository.getRecords(
      userId: 'test-user',
      prayerType: PrayerType.witr,
    );
    expect(records.length, 2);
    expect(records.every((r) => r.status == QazaStatus.completed), isTrue);
    expect(records.every((r) => r.completedAt != null), isTrue);
    expect(
      records.every(
        (r) => r.originalDate == DateTime(2026, 8, 20) || r.originalDate == DateTime(2026, 8, 21),
      ),
      isTrue,
    );
  });

  testWidgets('Completing Witr does not modify Isha records', (tester) async {
    final repository = InMemoryQazaRepository();
    await repository.addRecords([
      record(id: 'witr_1', prayer: PrayerType.witr, originalDate: DateTime(2026, 8, 20)),
      record(id: 'isha_1', prayer: PrayerType.isha, originalDate: DateTime(2026, 8, 19)),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: PendingDatesV2Screen(
          userId: 'test-user',
          service: QazaService(repository),
          prayer: PrayerType.witr,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final checkbox = find.byType(CheckboxListTile).first;
    await tester.ensureVisible(checkbox);
    await tester.tap(checkbox);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Complete 1 selected'));
    await tester.pumpAndSettle();

    final witr = await repository.getRecords(userId: 'test-user', prayerType: PrayerType.witr);
    final isha = await repository.getRecords(userId: 'test-user', prayerType: PrayerType.isha);

    expect(witr.single.status, QazaStatus.completed);
    expect(isha.single.status, QazaStatus.pending);
  });
}

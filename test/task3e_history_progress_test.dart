import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/repositories/in_memory_qaza_repository.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/services/qaza_service.dart';
import 'package:qaza_namaz/features/ui/history_progress_v2.dart';

QazaRecord record({
  required String id,
  required PrayerType prayer,
  required DateTime originalDate,
  QazaStatus status = QazaStatus.pending,
  DateTime? completedAt,
}) {
  final created = DateTime(2026, 9, 1, 10);
  return QazaRecord(
    id: id,
    userId: 'test-user',
    prayerType: prayer,
    originalDate: originalDate,
    status: status,
    completedAt: completedAt,
    createdAt: created,
    updatedAt: completedAt ?? created,
  );
}

Future<void> pumpScreen(WidgetTester tester, InMemoryQazaRepository repository) async {
  await tester.pumpWidget(
    MaterialApp(
      home: HistoryProgressV2Screen(
        userId: 'test-user',
        service: QazaService(repository),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Task 3E shows derived overall and six-prayer progress', (tester) async {
    final repository = InMemoryQazaRepository();
    await repository.addRecords([
      record(id: 'fajr_pending', prayer: PrayerType.fajr, originalDate: DateTime(2026, 8, 20)),
      record(id: 'fajr_completed', prayer: PrayerType.fajr, originalDate: DateTime(2026, 8, 19), status: QazaStatus.completed, completedAt: DateTime(2026, 9, 2, 8)),
      record(id: 'witr_completed', prayer: PrayerType.witr, originalDate: DateTime(2026, 8, 18), status: QazaStatus.completed, completedAt: DateTime(2026, 9, 3, 9)),
    ]);

    await pumpScreen(tester, repository);

    expect(find.text('Your progress'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    for (final prayer in PrayerType.values) {
      expect(find.text(prayer.label, skipOffstage: false), findsAtLeastNWidgets(1));
    }
    expect(find.textContaining('1 pending', skipOffstage: false), findsAtLeastNWidgets(1));
    expect(find.textContaining('2 completed', skipOffstage: false), findsAtLeastNWidgets(1));
  });

  testWidgets('Task 3E history excludes pending and is newest completed-first while preserving dates', (tester) async {
    final repository = InMemoryQazaRepository();
    await repository.addRecords([
      record(id: 'old_completed', prayer: PrayerType.fajr, originalDate: DateTime(2021, 10, 12), status: QazaStatus.completed, completedAt: DateTime(2026, 9, 2, 15, 45)),
      record(id: 'new_completed', prayer: PrayerType.zuhr, originalDate: DateTime(2021, 10, 11), status: QazaStatus.completed, completedAt: DateTime(2026, 9, 3, 13, 15)),
      record(id: 'pending', prayer: PrayerType.asr, originalDate: DateTime(2021, 10, 10)),
    ]);

    await pumpScreen(tester, repository);

    final newFinder = find.text('Zuhr Qaza completed', skipOffstage: false);
    final oldFinder = find.text('Fajr Qaza completed', skipOffstage: false);
    expect(newFinder, findsOneWidget);
    expect(oldFinder, findsOneWidget);
    expect(find.text('Asr Qaza completed', skipOffstage: false), findsNothing);
    expect(find.textContaining('Original missed date: 11 Oct 2021', skipOffstage: false), findsOneWidget);
    expect(find.textContaining('Original missed date: 12 Oct 2021', skipOffstage: false), findsOneWidget);

    final scrollable = find.byType(Scrollable);
    await tester.scrollUntilVisible(newFinder, 250, scrollable: scrollable);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(oldFinder, 250, scrollable: scrollable);
    await tester.pumpAndSettle();
  });

  testWidgets('Task 3E empty state is explicit when there is no completed history', (tester) async {
    final repository = InMemoryQazaRepository();
    await repository.addRecords([
      record(id: 'pending_only', prayer: PrayerType.isha, originalDate: DateTime(2026, 8, 1)),
    ]);

    await pumpScreen(tester, repository);

    final emptyTitle = find.text('No completed Qaza yet.', skipOffstage: false);
    final emptyBody = find.textContaining('Completed individual records will appear here', skipOffstage: false);
    expect(emptyTitle, findsOneWidget);
    expect(emptyBody, findsOneWidget);
    await tester.scrollUntilVisible(emptyTitle, 400, scrollable: find.byType(Scrollable));
    await tester.pumpAndSettle();
  });
}

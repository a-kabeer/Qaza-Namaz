import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/app_user.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/features/history/history_progress.dart';
import 'support/in_memory_qaza_repository.dart';

QazaRecord record({required String id, required PrayerType prayer, required DateTime originalDate, QazaStatus status = QazaStatus.pending, DateTime? completedAt}) {
  final created = DateTime(2026, 9, 1, 10);
  return QazaRecord(id: id, userId: 'test-user', prayerType: prayer, originalDate: originalDate, status: status, completedAt: completedAt, createdAt: created, updatedAt: completedAt ?? created);
}

Future<void> pumpScreen(WidgetTester tester, InMemoryQazaRepository repository) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      qazaRepositoryProvider.overrideWithValue(repository),
      authStateProvider.overrideWith((ref) => Stream.value(const AppUser(id: 'test-user', email: 'test@example.com'))),
    ],
    child: const MaterialApp(home: HistoryProgressScreen()),
  ));
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
    expect(find.text('Progress'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    for (final prayer in PrayerType.values) expect(find.text(prayer.label), findsOneWidget);
    expect(find.text('1 pending • 1 completed'), findsOneWidget);
    expect(find.text('0 pending • 1 completed'), findsOneWidget);
  });

  testWidgets('Task 3E history sorts by original date and shows pending/completed records', (tester) async {
    final repository = InMemoryQazaRepository();
    await repository.addRecords([
      record(id: 'old_completed', prayer: PrayerType.fajr, originalDate: DateTime(2021, 10, 12), status: QazaStatus.completed, completedAt: DateTime(2026, 9, 2, 15, 45)),
      record(id: 'new_completed', prayer: PrayerType.zuhr, originalDate: DateTime(2021, 10, 11), status: QazaStatus.completed, completedAt: DateTime(2026, 9, 3, 13, 15)),
      record(id: 'pending', prayer: PrayerType.asr, originalDate: DateTime(2021, 10, 10)),
    ]);
    await pumpScreen(tester, repository);
    final newFinder = find.text('Zuhr Qaza');
    final oldFinder = find.text('Fajr Qaza');
    expect(newFinder, findsOneWidget);
    expect(oldFinder, findsOneWidget);
    expect(find.text('Asr Qaza'), findsOneWidget);
    expect(find.textContaining('Original Qaza date: 11 Oct 2021'), findsOneWidget);
    expect(find.textContaining('Original Qaza date: 12 Oct 2021'), findsOneWidget);
    expect(find.textContaining('Status: Pending'), findsOneWidget);
    expect(tester.getCenter(oldFinder).dy, lessThan(tester.getCenter(newFinder).dy));
  });

  testWidgets('Task 3E empty state is explicit when there are no Qaza records', (tester) async {
    final repository = InMemoryQazaRepository();
    await pumpScreen(tester, repository);
    expect(find.text('No Qaza records yet.'), findsOneWidget);
    expect(find.textContaining('Your Qaza records will appear here'), findsOneWidget);
  });
}

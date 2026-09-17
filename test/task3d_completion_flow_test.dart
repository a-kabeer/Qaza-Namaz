import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/app_user.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/features/qaza/completion_screen.dart';
import 'package:qaza_namaz/features/qaza/namaz_wise_screen.dart';
import 'package:qaza_namaz/features/qaza/pending_dates_screen.dart';
import 'support/in_memory_qaza_repository.dart';

QazaRecord record({required String id, required PrayerType prayer, required DateTime originalDate, QazaStatus status = QazaStatus.pending, DateTime? completedAt}) {
  final now = DateTime(2026, 9, 14, 10);
  return QazaRecord(id: id, userId: 'test-user', prayerType: prayer, originalDate: originalDate, status: status, completedAt: completedAt, createdAt: now, updatedAt: now);
}

Widget scoped(Widget child, InMemoryQazaRepository repository) => ProviderScope(
      overrides: [
        qazaRepositoryProvider.overrideWithValue(repository),
        activeUserIdProvider.overrideWithValue('test-user'),
        authStateProvider.overrideWith((ref) => Stream.value(const AppUser(id: 'test-user', email: 'test@example.com'))),
      ],
      child: MaterialApp(home: child),
    );

Future<void> settleAuth(WidgetTester tester) async {
  await tester.pump();
  await tester.pumpAndSettle();
}

Future<void> pumpComplete(WidgetTester tester, InMemoryQazaRepository repository) async {
  await tester.pumpWidget(scoped(const CompleteQazaScreen(), repository));
  await settleAuth(tester);
}

Future<void> pumpNamazWise(WidgetTester tester, InMemoryQazaRepository repository) async {
  await tester.pumpWidget(scoped(const NamazWiseScreen(), repository));
  await settleAuth(tester);
}

void main() {
  testWidgets('Complete flow presents oldest pending Fajr record', (tester) async {
    final repository = InMemoryQazaRepository();
    await repository.addRecords([record(id: 'fajr_new', prayer: PrayerType.fajr, originalDate: DateTime(2026, 9, 10)), record(id: 'fajr_old', prayer: PrayerType.fajr, originalDate: DateTime(2026, 9, 2))]);
    await pumpComplete(tester, repository);
    expect(find.text('Oldest pending record'), findsOneWidget);
    expect(find.text('02 Sep 2026'), findsOneWidget);
    expect(find.text('Complete oldest pending'), findsOneWidget);
  });

  testWidgets('Completing oldest pending preserves original date and reduces pending records', (tester) async {
    final repository = InMemoryQazaRepository();
    await repository.addRecords([record(id: 'fajr_old', prayer: PrayerType.fajr, originalDate: DateTime(2026, 9, 2)), record(id: 'fajr_new', prayer: PrayerType.fajr, originalDate: DateTime(2026, 9, 10))]);
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
    await repository.addRecords([record(id: 'witr_pending', prayer: PrayerType.witr, originalDate: DateTime(2026, 8, 20))]);
    await pumpNamazWise(tester, repository);
    for (final prayer in PrayerType.values) expect(find.text(prayer.label), findsOneWidget);
    final witr = find.text('Witr');
    await tester.scrollUntilVisible(witr, 300, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(witr);
    await settleAuth(tester);
    expect(find.text('Witr Qaza'), findsOneWidget);
    expect(find.text('20 Aug 2026'), findsOneWidget);
    expect(find.text('Complete 0 selected'), findsNothing);
  });

  testWidgets('Namaz-wise flow supports multi-select completion for one prayer', (tester) async {
    final repository = InMemoryQazaRepository();
    await repository.addRecords([record(id: 'witr_1', prayer: PrayerType.witr, originalDate: DateTime(2026, 8, 20)), record(id: 'witr_2', prayer: PrayerType.witr, originalDate: DateTime(2026, 8, 21))]);
    await tester.pumpWidget(scoped(const PendingDatesScreen(prayer: PrayerType.witr), repository));
    await settleAuth(tester);
    expect(find.text('Complete 0 selected'), findsNothing);
    final boxes = find.byType(CheckboxListTile);
    expect(boxes, findsNWidgets(2));
    await tester.tap(boxes.at(0));
    await tester.pumpAndSettle();
    expect(find.text('Complete 1 Qaza'), findsOneWidget);
    await tester.tap(boxes.at(1));
    await tester.pumpAndSettle();
    expect(find.text('Complete 2 Qaza'), findsOneWidget);
    await tester.tap(find.text('Complete 2 Qaza'));
    await tester.pumpAndSettle();
    expect(find.text('Complete 2 Qaza'), findsNothing);
    final records = await repository.getRecords(userId: 'test-user', prayerType: PrayerType.witr);
    expect(records.length, 2);
    expect(records.every((r) => r.status == QazaStatus.completed), isTrue);
    expect(records.every((r) => r.completedAt != null), isTrue);
  });

  testWidgets('Completing Witr does not modify Isha records', (tester) async {
    final repository = InMemoryQazaRepository();
    await repository.addRecords([record(id: 'witr_1', prayer: PrayerType.witr, originalDate: DateTime(2026, 8, 20)), record(id: 'isha_1', prayer: PrayerType.isha, originalDate: DateTime(2026, 8, 19))]);
    await tester.pumpWidget(scoped(const PendingDatesScreen(prayer: PrayerType.witr), repository));
    await settleAuth(tester);
    final checkbox = find.byType(CheckboxListTile).first;
    await tester.tap(checkbox);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Complete 1 Qaza'));
    await tester.pumpAndSettle();
    final witr = await repository.getRecords(userId: 'test-user', prayerType: PrayerType.witr);
    final isha = await repository.getRecords(userId: 'test-user', prayerType: PrayerType.isha);
    expect(witr.single.status, QazaStatus.completed);
    expect(isha.single.status, QazaStatus.pending);
  });
}
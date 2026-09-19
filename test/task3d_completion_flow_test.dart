import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/test_app.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/app_user.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/features/qaza/qaza_tracker_screen.dart';
import 'support/complete_qaza_host.dart';
import 'support/in_memory_qaza_repository.dart';

QazaRecord record(
    {required String id,
    required PrayerType prayer,
    required DateTime originalDate,
    QazaStatus status = QazaStatus.pending,
    DateTime? completedAt}) {
  final now = DateTime(2026, 9, 14, 10);
  return QazaRecord(
      id: id,
      userId: 'test-user',
      prayerType: prayer,
      originalDate: originalDate,
      status: status,
      completedAt: completedAt,
      createdAt: now,
      updatedAt: now);
}

Widget scoped(Widget child, InMemoryQazaRepository repository) => ProviderScope(
      overrides: [
        qazaRepositoryProvider.overrideWithValue(repository),
        activeUserIdProvider.overrideWithValue('test-user'),
        authStateProvider.overrideWith((ref) => Stream.value(
            const AppUser(id: 'test-user', email: 'test@example.com'))),
      ],
      child: TestApp(home: child),
    );

Future<void> settleAuth(WidgetTester tester) async {
  await tester.pump();
  await tester.pumpAndSettle();
}

Future<void> pumpComplete(
    WidgetTester tester, InMemoryQazaRepository repository) async {
  await tester.pumpWidget(scoped(const CompleteQazaHost(), repository));
  await settleAuth(tester);
}

Future<void> pumpTracker(
    WidgetTester tester, InMemoryQazaRepository repository) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(scoped(const QazaTrackerScreen(), repository));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
}

void main() {
  testWidgets('Complete flow presents the latest pending Fajr record',
      (tester) async {
    final repository = InMemoryQazaRepository();
    await repository.addRecords([
      record(
          id: 'fajr_new',
          prayer: PrayerType.fajr,
          originalDate: DateTime(2026, 9, 10)),
      record(
          id: 'fajr_old',
          prayer: PrayerType.fajr,
          originalDate: DateTime(2026, 9, 2))
    ]);
    await pumpComplete(tester, repository);
    expect(find.text('Latest pending record'), findsOneWidget);
    expect(find.text('10 Sep 2026'), findsOneWidget);
    expect(find.text('Complete latest pending'), findsOneWidget);
  });

  testWidgets(
      'Completing the latest pending preserves its date and reduces pending records',
      (tester) async {
    final repository = InMemoryQazaRepository();
    await repository.addRecords([
      record(
          id: 'fajr_old',
          prayer: PrayerType.fajr,
          originalDate: DateTime(2026, 9, 2)),
      record(
          id: 'fajr_new',
          prayer: PrayerType.fajr,
          originalDate: DateTime(2026, 9, 10))
    ]);
    await pumpComplete(tester, repository);
    await tester.tap(find.text('Complete latest pending'));
    await tester.pumpAndSettle();
    final records = await repository.getRecords(userId: 'test-user');
    final completed = records.singleWhere((r) => r.id == 'fajr_new');
    final pending =
        records.where((r) => r.status == QazaStatus.pending).toList();
    expect(completed.status, QazaStatus.completed);
    expect(completed.originalDate, DateTime(2026, 9, 10));
    expect(completed.completedAt, isNotNull);
    expect(pending.map((r) => r.id), contains('fajr_old'));
  });

  testWidgets('Qaza workspace offers every prayer as a filter', (tester) async {
    final repository = InMemoryQazaRepository();
    await repository.addRecords([
      record(
          id: 'witr_pending',
          prayer: PrayerType.witr,
          originalDate: DateTime(2026, 8, 20))
    ]);
    await pumpTracker(tester, repository);
    for (final prayer in PrayerType.values) {
      expect(find.widgetWithText(FilterChip, prayer.label), findsOneWidget);
    }
    expect(find.text('20 Aug 2026'), findsOneWidget);
  });

  testWidgets('Qaza workspace supports multi-select completion for one prayer',
      (tester) async {
    final repository = InMemoryQazaRepository();
    await repository.addRecords([
      record(
          id: 'witr_1',
          prayer: PrayerType.witr,
          originalDate: DateTime(2026, 8, 20)),
      record(
          id: 'witr_2',
          prayer: PrayerType.witr,
          originalDate: DateTime(2026, 8, 21))
    ]);
    await pumpTracker(tester, repository);

    await tester.tap(find.widgetWithText(FilterChip, 'Witr'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    final boxes = find.byType(Checkbox);
    expect(boxes, findsNWidgets(2));
    await tester.tap(boxes.at(0));
    await tester.pump();
    expect(find.text('Complete 1 Qaza'), findsOneWidget);
    await tester.tap(boxes.at(1));
    await tester.pump();
    expect(find.text('Complete 2 Qaza'), findsOneWidget);

    await tester.tap(find.byKey(const Key('qaza_tracker_complete_selected')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    final records = await repository.getRecords(
        userId: 'test-user', prayerType: PrayerType.witr);
    expect(records.length, 2);
    expect(records.every((r) => r.status == QazaStatus.completed), isTrue);
    expect(records.every((r) => r.completedAt != null), isTrue);
  });

  testWidgets('Completing Witr does not modify Isha records', (tester) async {
    final repository = InMemoryQazaRepository();
    await repository.addRecords([
      record(
          id: 'witr_1',
          prayer: PrayerType.witr,
          originalDate: DateTime(2026, 8, 20)),
      record(
          id: 'isha_1',
          prayer: PrayerType.isha,
          originalDate: DateTime(2026, 8, 19))
    ]);
    await pumpTracker(tester, repository);

    await tester.tap(find.widgetWithText(FilterChip, 'Witr'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    await tester.tap(find.byKey(const Key('qaza_tracker_complete_selected')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    final witr = await repository.getRecords(
        userId: 'test-user', prayerType: PrayerType.witr);
    final isha = await repository.getRecords(
        userId: 'test-user', prayerType: PrayerType.isha);
    expect(witr.single.status, QazaStatus.completed);
    expect(isha.single.status, QazaStatus.pending);
  });
}

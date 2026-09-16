import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/app_user.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/features/qaza/pending_dates_screen.dart';
import 'support/in_memory_qaza_repository.dart';

QazaRecord record({required String id, required DateTime originalDate}) {
  final now = DateTime(2026, 9, 16, 10);
  return QazaRecord(
    id: id,
    userId: 'test-user',
    prayerType: PrayerType.fajr,
    originalDate: originalDate,
    createdAt: now,
    updatedAt: now,
  );
}

Widget scoped(Widget child, InMemoryQazaRepository repository) => ProviderScope(
      overrides: [
        qazaRepositoryProvider.overrideWithValue(repository),
        authStateProvider.overrideWith(
          (ref) => Stream.value(
            const AppUser(id: 'test-user', email: 'test@example.com'),
          ),
        ),
      ],
      child: MaterialApp(home: child),
    );

Future<void> pumpScreen(
  WidgetTester tester,
  InMemoryQazaRepository repository,
) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    scoped(
      const PendingDatesScreen(prayer: PrayerType.fajr),
      repository,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('selected Qaza shows the sticky completion action with count',
      (tester) async {
    final repository = InMemoryQazaRepository();
    await repository.addRecords([
      record(id: 'fajr_1', originalDate: DateTime(2026, 9, 1)),
      record(id: 'fajr_2', originalDate: DateTime(2026, 9, 2)),
    ]);
    await pumpScreen(tester, repository);

    expect(find.byKey(const Key('complete_selected_qaza_button')), findsNothing);

    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pumpAndSettle();

    expect(find.text('Complete 1 Qaza'), findsOneWidget);
    final action = find.byKey(const Key('complete_selected_qaza_button'));
    expect(action, findsOneWidget);
    expect(tester.getBottomRight(action).dy, closeTo(800, 50));
  });

  testWidgets('sticky completion action remains accessible while scrolling',
      (tester) async {
    final repository = InMemoryQazaRepository();
    await repository.addRecords([
      for (var index = 0; index < 40; index++)
        record(
          id: 'fajr_$index',
          originalDate: DateTime(2026, 8, 1).add(Duration(days: index)),
        ),
    ]);
    await pumpScreen(tester, repository);

    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pumpAndSettle();
    expect(find.text('Complete 1 Qaza'), findsOneWidget);

    final list = find.byType(Scrollable).first;
    await tester.drag(list, const Offset(0, -1200));
    await tester.pumpAndSettle();

    final action = find.byKey(const Key('complete_selected_qaza_button'));
    expect(action, findsOneWidget);
    expect(tester.getCenter(action).dy, greaterThan(650));
    expect(find.text('Complete 1 Qaza'), findsOneWidget);
  });

  testWidgets('completion clears selection and hides the action after refresh',
      (tester) async {
    final repository = InMemoryQazaRepository();
    await repository.addRecords([
      record(id: 'fajr_1', originalDate: DateTime(2026, 9, 1)),
      record(id: 'fajr_2', originalDate: DateTime(2026, 9, 2)),
    ]);
    await pumpScreen(tester, repository);

    final boxes = find.byType(CheckboxListTile);
    await tester.tap(boxes.at(0));
    await tester.tap(boxes.at(1));
    await tester.pumpAndSettle();
    expect(find.text('Complete 2 Qaza'), findsOneWidget);

    await tester.tap(find.byKey(const Key('complete_selected_qaza_button')));
    await tester.pumpAndSettle();

    final records = await repository.getRecords(userId: 'test-user');
    expect(records.every((item) => item.status == QazaStatus.completed), isTrue);
    expect(find.byKey(const Key('complete_selected_qaza_button')), findsNothing);
    expect(find.text('Complete 2 Qaza'), findsNothing);
  });

  testWidgets('completion button stays visible in a loading state while processing',
      (tester) async {
    final repository = InMemoryQazaRepository();
    await repository.addRecord(
      record(id: 'fajr_1', originalDate: DateTime(2026, 9, 1)),
    );
    await pumpScreen(tester, repository);

    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('complete_selected_qaza_button')));
    await tester.pump();

    expect(find.byKey(const Key('complete_selected_qaza_button')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Completing 1 Qaza…'), findsOneWidget);
  });
}

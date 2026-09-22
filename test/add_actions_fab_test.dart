import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/app_user.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/features/qaza/add_qaza_screen.dart';
import 'package:qaza_namaz/features/qaza/qaza_tracker_screen.dart';
import 'package:qaza_namaz/features/shell/workspace_shell.dart';

import 'support/in_memory_qaza_repository.dart';
import 'support/test_app.dart';

QazaRecord _record(PrayerType prayer) => QazaRecord(
      id: prayer.name + '_1',
      userId: 'u1',
      prayerType: prayer,
      originalDate: DateTime(2026, 1, 1),
      createdAt: DateTime(2026, 9, 18),
      updatedAt: DateTime(2026, 9, 18),
    );

void main() {
  Future<ProviderContainer> pumpQazaTab(WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    final repository = InMemoryQazaRepository();
    await repository.addRecords([for (final p in PrayerType.values) _record(p)]);

    final container = ProviderContainer(overrides: [
      qazaRepositoryProvider.overrideWithValue(repository),
      activeUserIdProvider.overrideWithValue('u1'),
      authStateProvider.overrideWith(
        (ref) => Stream.value(const AppUser(id: 'u1', email: 'u1@example.com')),
      ),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const TestApp(home: QazaTrackerScreen()),
    ));
    await tester.pumpAndSettle();
    container.read(workspaceDestinationProvider.notifier).state =
        WorkspaceDestination.qaza;
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('Qaza uses a single Add FAB', (tester) async {
    await pumpQazaTab(tester);

    expect(find.byKey(const Key('qaza_tracker_add_fab')), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    expect(find.byKey(const Key('add_actions_fab')), findsNothing);
    expect(find.byKey(const Key('fab_action_add_qaza')), findsNothing);
    expect(find.byKey(const Key('fab_action_calculate_qaza')), findsNothing);
  });

  testWidgets('Add FAB opens the existing Add Qaza screen', (tester) async {
    await pumpQazaTab(tester);

    await tester.tap(find.byKey(const Key('qaza_tracker_add_fab')));
    await tester.pumpAndSettle();

    expect(find.byType(AddQazaScreen), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/app_user.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/features/qaza/qaza_tracker_controller.dart';
import 'package:qaza_namaz/features/shell/workspace_shell.dart';

import 'support/in_memory_qaza_repository.dart';
import 'support/test_app.dart';

QazaRecord _record(PrayerType prayer, int day) => QazaRecord(
      id: prayer.name + '_' + day.toString(),
      userId: 'u1',
      prayerType: prayer,
      originalDate: DateTime(2026, 1, day),
      createdAt: DateTime(2026, 9, 18),
      updatedAt: DateTime(2026, 9, 18),
    );

void main() {
  Future<ProviderContainer> pumpShell(
    WidgetTester tester,
    InMemoryQazaRepository repository,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    final container = ProviderContainer(overrides: [
      qazaRepositoryProvider.overrideWithValue(repository),
      activeUserIdProvider.overrideWithValue('u1'),
      authStateProvider.overrideWith(
        (ref) => Stream.value(const AppUser(id: 'u1', email: 'u1@example.com')),
      ),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(home: WorkspaceShell()),
      ),
    );
    await tester.pumpAndSettle();
    container.read(workspaceDestinationProvider.notifier).state =
        WorkspaceDestination.qaza;
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('Qaza has a single add FAB', (tester) async {
    final repository = InMemoryQazaRepository();
    await repository.addRecords([
      _record(PrayerType.fajr, 1),
    ]);
    await pumpShell(tester, repository);

    expect(find.byKey(const Key('qaza_tracker_add_fab')), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
  });

  testWidgets('selection mode hides the FAB and shows bulk actions',
      (tester) async {
    final repository = InMemoryQazaRepository();
    await repository.addRecords([
      _record(PrayerType.fajr, 1),
      _record(PrayerType.zuhr, 2),
    ]);
    final container = await pumpShell(tester, repository);

    await tester.longPress(
      find.byKey(const Key('qaza_record_' + 'fajr_1')),
    );
    await tester.pump();

    expect(container.read(qazaTrackerControllerProvider).selected, hasLength(1));
    expect(find.byKey(const Key('qaza_tracker_add_fab')), findsNothing);
    expect(find.byKey(const Key('qaza_tracker_complete_selected')), findsOneWidget);
    expect(find.byKey(const Key('qaza_tracker_delete_selected')), findsOneWidget);
  });

  testWidgets('exiting selection restores the add FAB', (tester) async {
    final repository = InMemoryQazaRepository();
    await repository.addRecords([
      _record(PrayerType.fajr, 1),
    ]);
    final container = await pumpShell(tester, repository);

    await tester.longPress(find.byKey(const Key('qaza_record_fajr_1')));
    await tester.pump();
    container.read(qazaTrackerControllerProvider.notifier).exitSelectionMode();
    await tester.pump();

    expect(find.byKey(const Key('qaza_tracker_add_fab')), findsOneWidget);
  });
}

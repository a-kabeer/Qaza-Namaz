import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/domain/entities/app_user.dart';
import 'package:qaza_namaz/features/settings/settings_screen.dart';

import '../../support/in_memory_qaza_repository.dart';
import '../../support/test_app.dart';

void main() {
  testWidgets('Settings exposes one canonical entry per destination',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          qazaRepositoryProvider.overrideWithValue(InMemoryQazaRepository()),
          authStateProvider.overrideWith(
            (ref) => Stream.value(
              const AppUser(id: 'test-user', email: 'test@example.com'),
            ),
          ),
        ],
        child: const TestApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings_account')), findsOneWidget);
    expect(find.byKey(const Key('settings_notifications')), findsOneWidget);
    expect(find.byKey(const Key('settings_data_cloud')), findsOneWidget);
    expect(find.byKey(const Key('settings_about')), findsOneWidget);

    expect(find.text('Preferences'), findsOneWidget);
    expect(find.text('Data & Storage'), findsOneWidget);
    expect(find.text('Export data'), findsNothing);
    expect(find.text('Import data'), findsNothing);
    expect(find.byType(SettingsNavRow), findsNWidgets(4));
  });

  testWidgets('Data & Cloud owns the combined export/import destination',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          qazaRepositoryProvider.overrideWithValue(InMemoryQazaRepository()),
          authStateProvider.overrideWith(
            (ref) => Stream.value(
              const AppUser(id: 'test-user', email: 'test@example.com'),
            ),
          ),
        ],
        child: const TestApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settings_data_cloud')));
    await tester.pumpAndSettle();

    expect(find.text('Cloud Sync'), findsOneWidget);
    expect(find.text('Export & Import'), findsOneWidget);
  });
}

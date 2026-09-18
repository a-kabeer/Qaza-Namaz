import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/in_memory_qaza_repository.dart';
import 'support/test_app.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/domain/entities/app_user.dart';
import 'package:qaza_namaz/features/settings/settings_screen.dart';

void main() {
  testWidgets(
      'Settings presents clear grouped sections and existing destinations',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Settings now reads the ledger size for the reset action, so the
          // repository has to be a test double rather than the Firebase one.
          qazaRepositoryProvider.overrideWithValue(InMemoryQazaRepository()),
          authStateProvider.overrideWith(
            (ref) => Stream.value(
                const AppUser(id: 'test-user', email: 'test@example.com')),
          ),
        ],
        child: const TestApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    for (final section in [
      'Appearance',
      'Language',
      'Account',
      'Prayer',
      'Notifications',
      'Data & Storage',
      'About',
    ]) {
      expect(find.text(section), findsWidgets);
    }

    expect(find.byKey(const Key('settings_theme_mode')), findsOneWidget);
    expect(find.byKey(const Key('settings_language')), findsOneWidget);
    expect(find.text('Prayer & Fiqh Rules'), findsOneWidget);
    expect(find.text('Data & Cloud'), findsOneWidget);
    expect(find.text('General'), findsNothing);
  });
}

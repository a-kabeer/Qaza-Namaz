import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/domain/entities/app_user.dart';
import 'package:qaza_namaz/features/settings/settings_screen.dart';

void main() {
  testWidgets('Settings presents clear grouped sections and existing destinations', (tester) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream.value(const AppUser(id: 'test-user', email: 'test@example.com')),
          ),
        ],
        child: const MaterialApp(home: SettingsScreen()),
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
      expect(find.text(section), section == 'Account' ? findsNWidgets(2) : findsOneWidget);
    }

    expect(find.byKey(const Key('settings_theme_mode')), findsOneWidget);
    expect(find.byKey(const Key('settings_language')), findsOneWidget);
    expect(find.text('Prayer & Fiqh Rules'), findsOneWidget);
    expect(find.text('Data & Cloud'), findsOneWidget);
    expect(find.text('General'), findsNothing);
  });
}

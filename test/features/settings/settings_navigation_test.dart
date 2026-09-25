import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/domain/entities/app_user.dart';
import 'package:qaza_namaz/features/settings/settings_screen.dart';
import 'package:qaza_namaz/core/widgets/settings_components.dart';

import '../../support/in_memory_qaza_repository.dart';
import '../../support/test_app.dart';

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Settings exposes the simplified user-facing destinations',
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

    expect(find.byKey(const Key('settings_profile')), findsOneWidget);
    expect(find.byKey(const Key('settings_notifications')), findsOneWidget);
    expect(find.byKey(const Key('settings_about')), findsOneWidget);
    expect(find.byKey(const Key('settings_language')), findsOneWidget);
    expect(find.byKey(const Key('settings_reset_qaza_counter')), findsOneWidget);

    expect(find.byKey(const Key('settings_account')), findsNothing);
    expect(find.byKey(const Key('settings_privacy_security')), findsNothing);
    expect(find.byKey(const Key('settings_data_cloud')), findsNothing);
    expect(find.text('Preferences'), findsNothing);
    expect(find.text('Data & Storage'), findsNothing);
    expect(find.text('Export data'), findsNothing);
    expect(find.text('Import data'), findsNothing);
    expect(find.byType(SettingsNavRow), findsNWidgets(3));
  });
}

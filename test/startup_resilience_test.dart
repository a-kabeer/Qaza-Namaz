import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/domain/entities/user_profile.dart';
import 'package:qaza_namaz/features/onboarding/language_selection_screen.dart';
import 'package:qaza_namaz/features/onboarding/profile_setup_screen.dart';
import 'package:qaza_namaz/features/onboarding/startup_gate.dart';
import 'package:qaza_namaz/features/shell/workspace_shell.dart';

import 'support/in_memory_qaza_repository.dart';
import 'support/test_app.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      // Prevent the unrelated prayer-time setup prompt from overlaying startup.
      'qaza_prayer_times_setup_prompt_seen': true,
    });
  });

  Future<void> pumpStartup(
    WidgetTester tester, {
    required UserProfile? profile,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProfileProvider.overrideWithValue(
            AsyncValue<UserProfile?>.data(profile),
          ),
          qazaRepositoryProvider.overrideWithValue(InMemoryQazaRepository()),
          activeUserIdProvider.overrideWithValue(UserProfile.localLedgerUserId),
        ],
        child: const TestApp(home: StartupGate()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('fresh installation starts with language selection',
      (tester) async {
    await pumpStartup(tester, profile: null);

    expect(find.byType(LanguageSelectionScreen), findsOneWidget);
    expect(find.byType(ProfileSetupScreen), findsNothing);
    expect(find.text('Continue with Google'), findsNothing);
    expect(find.text('Continue as Guest'), findsNothing);
  });

  testWidgets('an incomplete profile resumes profile setup', (tester) async {
    const profile = UserProfile(
      languageCode: 'en',
      onboardingCompleted: false,
    );

    await pumpStartup(tester, profile: profile);

    expect(find.byType(ProfileSetupScreen), findsOneWidget);
    expect(find.byType(LanguageSelectionScreen), findsNothing);
  });

  testWidgets('a completed profile opens the normal workspace', (tester) async {
    final profile = UserProfile(
      languageCode: 'en',
      gender: Gender.male,
      madhab: Madhab.hanafi,
      dateOfBirth: DateTime(2000, 1, 1),
      pubertyAge: 12,
      startPrayingAge: 18,
      witrIncluded: true,
      onboardingCompleted: true,
    );

    await pumpStartup(tester, profile: profile);

    expect(find.byType(WorkspaceShell), findsOneWidget);
    expect(find.text('Continue with Google'), findsNothing);
    expect(find.text('Continue as Guest'), findsNothing);
  });
}

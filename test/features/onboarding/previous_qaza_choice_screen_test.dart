import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/features/onboarding/previous_qaza_choice_screen.dart';
import 'package:qaza_namaz/features/onboarding/profile_setup_screen.dart';
import 'package:qaza_namaz/features/shell/workspace_shell.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

void main() {
  Widget app(Widget home) => ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      );

  testWidgets('setup choice opens Profile Setup', (tester) async {
    await tester.pumpWidget(
      app(
        PreviousQazaChoiceScreen(
          setupScreenBuilder: () => const ProfileSetupScreen(
            languageCode: 'en',
          ),
        ),
      ),
    );

    expect(
      find.byKey(const Key('onboarding_previous_qaza_setup')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('onboarding_previous_qaza_skip')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('onboarding_previous_qaza_setup')));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileSetupScreen), findsOneWidget);
  });

  testWidgets('start without previous Qaza goes directly to home',
      (tester) async {
    await tester.pumpWidget(
      app(
        PreviousQazaChoiceScreen(
          setupScreenBuilder: () => const ProfileSetupScreen(
            languageCode: 'en',
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('onboarding_previous_qaza_skip')));
    await tester.pumpAndSettle();

    expect(find.byType(PreviousQazaChoiceScreen), findsNothing);
    expect(find.byType(ProfileSetupScreen), findsNothing);
    expect(find.byType(WorkspaceShell), findsOneWidget);
    expect(find.byKey(const Key('home_empty_state')), findsOneWidget);
  });
}

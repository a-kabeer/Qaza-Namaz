import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/features/onboarding/previous_qaza_choice_screen.dart';
import 'package:qaza_namaz/features/onboarding/profile_setup_screen.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

void main() {
  Widget app(Widget home) => MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      );

  testWidgets('previous qaza choice opens Profile and supports back', (tester) async {
    await tester.pumpWidget(
      app(
        PreviousQazaChoiceScreen(
          languageCode: 'en',
          nextScreenBuilder: (_) => const ProfileSetupScreen(
            languageCode: 'en',
            previousQazaChoice: PreviousQazaChoice.setup,
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
    expect(find.byKey(const Key('onboarding_previous_qaza_current')), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('onboarding_previous_qaza_setup')),
      findsOneWidget,
    );
  });

  testWidgets('previous qaza skip choice opens Profile without qaza setup', (tester) async {
    await tester.pumpWidget(
      app(
        PreviousQazaChoiceScreen(
          languageCode: 'en',
          nextScreenBuilder: (_) => const ProfileSetupScreen(
            languageCode: 'en',
            previousQazaChoice: PreviousQazaChoice.skip,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('onboarding_previous_qaza_skip')));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileSetupScreen), findsOneWidget);
    expect(
      find.text('Start without previous Qaza'),
      findsOneWidget,
    );
  });

  testWidgets('change mode returns the selected choice to caller', (tester) async {
    PreviousQazaChoice? selected;

    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              selected = await Navigator.of(context).push<PreviousQazaChoice>(
                MaterialPageRoute<PreviousQazaChoice>(
                  builder: (_) => const PreviousQazaChoiceScreen(
                    languageCode: 'en',
                    initialChoice: PreviousQazaChoice.setup,
                    popOnSelection: true,
                  ),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding_previous_qaza_skip')));
    await tester.pumpAndSettle();

    expect(selected, PreviousQazaChoice.skip);
  });
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/domain/entities/user_profile.dart';
import 'package:qaza_namaz/domain/repositories/user_profile_repository.dart';
import 'package:qaza_namaz/features/onboarding/language_selection_screen.dart';
import 'package:qaza_namaz/features/onboarding/previous_qaza_choice_screen.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

class _FakeUserProfileRepository implements UserProfileRepository {
  _FakeUserProfileRepository({this.saveCompleter});

  final Completer<void>? saveCompleter;
  UserProfile? savedProfile;
  int saveCount = 0;

  @override
  Future<UserProfile?> load() async => savedProfile;

  @override
  Future<void> save(UserProfile profile) async {
    saveCount++;
    savedProfile = profile;
    if (saveCompleter != null) {
      await saveCompleter!.future;
    }
  }

  @override
  Future<void> clear() async {}
}

Widget _app({
  UserProfileRepository? repository,
}) {
  return ProviderScope(
    overrides: [
      if (repository != null)
        userProfileRepositoryProvider.overrideWithValue(repository),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const LanguageSelectionScreen(),
    ),
  );
}

void main() {
  testWidgets('selecting a language updates preview without navigation',
      (tester) async {
    final repository = _FakeUserProfileRepository();

    await tester.pumpWidget(_app(repository: repository));
    await tester.tap(
      find.byKey(const Key('onboarding_language_ur')),
    );
    await tester.pump();

    expect(find.byType(LanguageSelectionScreen), findsOneWidget);
    expect(
      find.byType(PreviousQazaChoiceScreen),
      findsNothing,
    );
    expect(repository.saveCount, 0);
    expect(
      find.byKey(const Key('onboarding_language_ur')),
      findsOneWidget,
    );
  });

  testWidgets('Continue persists the selected language and navigates',
      (tester) async {
    final repository = _FakeUserProfileRepository();

    await tester.pumpWidget(_app(repository: repository));
    await tester.tap(
      find.byKey(const Key('onboarding_language_ur')),
    );
    await tester.pump();

    await tester.tap(find.text('جاری رکھیں'));
    await tester.pumpAndSettle();

    expect(repository.saveCount, 1);
    expect(repository.savedProfile?.languageCode, 'ur');
    expect(repository.savedProfile?.onboardingCompleted, isFalse);

    final next = tester.widget<PreviousQazaChoiceScreen>(
      find.byType(PreviousQazaChoiceScreen),
    );
    expect(next.languageCode, 'ur');
    expect(find.byType(PreviousQazaChoiceScreen), findsOneWidget);
  });

  testWidgets('Continue uses the selected language and prevents duplicate saves',
      (tester) async {
    final completer = Completer<void>();
    final repository = _FakeUserProfileRepository(
      saveCompleter: completer,
    );

    await tester.pumpWidget(_app(repository: repository));
    await tester.tap(
      find.byKey(const Key('onboarding_language_ur')),
    );
    await tester.pump();

    final continueButton = find.widgetWithText(
      FilledButton,
      'جاری رکھیں',
    );
    await tester.tap(continueButton);
    await tester.pump();

    expect(repository.saveCount, 1);
    expect(find.byType(PreviousQazaChoiceScreen), findsNothing);

    await tester.tap(continueButton);
    await tester.pump();

    expect(repository.saveCount, 1);
    expect(find.byType(PreviousQazaChoiceScreen), findsNothing);

    completer.complete();
    await tester.pumpAndSettle();

    expect(find.byType(PreviousQazaChoiceScreen), findsOneWidget);
    expect(repository.saveCount, 1);
  });
}

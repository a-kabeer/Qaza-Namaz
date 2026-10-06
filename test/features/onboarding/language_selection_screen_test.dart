import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/domain/entities/user_profile.dart';
import 'package:qaza_namaz/domain/repositories/user_profile_repository.dart';
import 'package:qaza_namaz/features/onboarding/language_selection_screen.dart';
import 'package:qaza_namaz/features/onboarding/profile_setup_screen.dart';
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
  Future<void> saveLocalOnly(UserProfile profile) => save(profile);

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
    child: Consumer(
      builder: (context, ref, child) => MaterialApp(
        locale: ref.watch(localeProvider),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const LanguageSelectionScreen(),
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('selecting a language updates preview without navigation or persistence',
      (tester) async {
    final repository = _FakeUserProfileRepository();

    await tester.pumpWidget(_app(repository: repository));
    await tester.tap(
      find.byKey(const Key('onboarding_language_ur')),
    );
    await tester.pump();

    final prefs = await SharedPreferences.getInstance();

    expect(find.byType(LanguageSelectionScreen), findsOneWidget);
    expect(find.byType(ProfileSetupScreen), findsNothing);
    expect(repository.saveCount, 0);
    expect(prefs.getString(LocaleNotifier.storageKey), isNull);
    expect(
      find.byKey(const Key('onboarding_language_ur')),
      findsOneWidget,
    );
    expect(find.text('جاری رکھیں'), findsOneWidget);
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

    final prefs = await SharedPreferences.getInstance();

    expect(repository.saveCount, 1);
    expect(repository.savedProfile?.languageCode, 'ur');
    expect(repository.savedProfile?.onboardingCompleted, isFalse);
    expect(prefs.getString(LocaleNotifier.storageKey), 'ur');

    expect(find.byType(ProfileSetupScreen), findsOneWidget);
    expect(
      find.text('اپنا پروفائل مکمل کریں'),
      findsOneWidget,
    );
  });

  testWidgets('Continue prevents duplicate saves and navigation while saving',
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

    final continueButton = find.byType(FilledButton);
    await tester.tap(continueButton);
    await tester.pump();

    expect(repository.saveCount, 1);
    expect(find.byType(ProfileSetupScreen), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.tap(continueButton);
    await tester.pump();

    expect(repository.saveCount, 1);
    expect(find.byType(ProfileSetupScreen), findsNothing);

    completer.complete();
    await tester.pumpAndSettle();

    expect(find.byType(ProfileSetupScreen), findsOneWidget);
    expect(repository.saveCount, 1);
  });
}

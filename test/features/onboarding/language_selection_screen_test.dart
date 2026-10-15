import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/widgets/app_snackbar.dart';
import 'package:qaza_namaz/domain/entities/user_profile.dart';
import 'package:qaza_namaz/domain/repositories/user_profile_repository.dart';
import 'package:qaza_namaz/features/onboarding/language_selection_screen.dart';
import 'package:qaza_namaz/features/onboarding/profile_setup_screen.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

class _FakeUserProfileRepository implements UserProfileRepository {
  _FakeUserProfileRepository({this.saveCompleter, this.saveError});

  final Completer<void>? saveCompleter;
  final Object? saveError;
  UserProfile? savedProfile;
  int saveCount = 0;

  @override
  Future<UserProfile?> load() async => savedProfile;

  @override
  Future<void> save(UserProfile profile) async {
    saveCount++;
    if (saveError != null) throw saveError!;
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

Future<void> _chooseLanguage(
  WidgetTester tester,
  String languageCode,
) async {
  final selector = find.byKey(const Key('onboarding_language_selector'));
  await tester.tap(
    find.descendant(
      of: selector,
      matching: find.byType(DropdownButton<Locale>),
    ),
  );
  await tester.pumpAndSettle();

  final label = switch (languageCode) {
    'ur' => 'اردو',
    'ur_Latn' => 'Urdu',
    'ar' => 'العربية',
    _ => languageCode,
  };
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Widget _app({
  UserProfileRepository? repository,
  LocaleNotifier Function()? localeNotifier,
}) {
  return ProviderScope(
    overrides: [
      if (repository != null)
        userProfileRepositoryProvider.overrideWithValue(repository),
      if (localeNotifier != null) localeProvider.overrideWith(localeNotifier),
    ],
    child: Consumer(
      builder: (context, ref, child) => MaterialApp(
        locale: ref.watch(localeProvider),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => AppScaffoldMessenger(
          key: appScaffoldMessengerKey,
          child: child!,
        ),
        home: const LanguageSelectionScreen(),
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
      'selecting a language updates preview without navigation or persistence',
      (tester) async {
    final repository = _FakeUserProfileRepository();

    await tester.pumpWidget(_app(repository: repository));
    await _chooseLanguage(tester, 'ur');

    final prefs = await SharedPreferences.getInstance();

    expect(find.byType(LanguageSelectionScreen), findsOneWidget);
    expect(find.byType(ProfileSetupScreen), findsNothing);
    expect(repository.saveCount, 0);
    expect(prefs.getString(LocaleNotifier.storageKey), isNull);
    expect(find.text('اردو'), findsOneWidget);
    expect(find.text('جاری رکھیں'), findsOneWidget);
  });

  testWidgets('Continue persists the selected language and navigates',
      (tester) async {
    final repository = _FakeUserProfileRepository();

    await tester.pumpWidget(_app(repository: repository));
    await _chooseLanguage(tester, 'ur');

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
    await _chooseLanguage(tester, 'ur');

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

  testWidgets('Arabic can be selected during onboarding', (tester) async {
    final repository = _FakeUserProfileRepository();
    await tester.pumpWidget(_app(repository: repository));
    await _chooseLanguage(tester, 'ar');
    expect(find.text('اختر لغتك'), findsOneWidget);
    expect(find.text('العربية'), findsOneWidget);
    await tester.tap(find.text('متابعة'));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(repository.savedProfile?.languageCode, 'ar');
    expect(prefs.getString(LocaleNotifier.storageKey), 'ar');
    expect(find.byType(ProfileSetupScreen), findsOneWidget);
  });

  testWidgets('Roman Urdu is labelled Urdu and persists its script identifier',
      (tester) async {
    final repository = _FakeUserProfileRepository();
    await tester.pumpWidget(_app(repository: repository));

    await _chooseLanguage(tester, 'ur_Latn');
    expect(find.text('Urdu'), findsOneWidget);

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(repository.saveCount, 1);
    expect(repository.savedProfile?.languageCode, 'ur');
    expect(prefs.getString(LocaleNotifier.storageKey), 'ur_Latn');
    expect(find.byType(ProfileSetupScreen), findsOneWidget);
  });

  testWidgets('profile-save failure does not persist locale or navigate',
      (tester) async {
    final repository = _FakeUserProfileRepository(
      saveError: StateError('profile storage unavailable'),
    );

    await tester.pumpWidget(_app(repository: repository));
    await _chooseLanguage(tester, 'ur');
    await tester.tap(find.text('جاری رکھیں'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(repository.saveCount, 1);
    expect(prefs.getString(LocaleNotifier.storageKey), isNull);
    expect(find.byType(ProfileSetupScreen), findsNothing);
    expect(
      find.text(lookupAppLocalizations(const Locale('ur')).errorStorage),
      findsOneWidget,
    );
  });

  testWidgets('locale-persistence failure does not complete onboarding',
      (tester) async {
    final repository = _FakeUserProfileRepository();
    await tester.pumpWidget(
      _app(
        repository: repository,
        localeNotifier: _FailingLocaleNotifier.new,
      ),
    );

    await _chooseLanguage(tester, 'ur');
    await tester.tap(
      find.text(lookupAppLocalizations(const Locale('ur')).commonContinue),
    );
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(repository.saveCount, 1);
    expect(repository.savedProfile?.languageCode, 'ur');
    expect(prefs.getString(LocaleNotifier.storageKey), isNull);
    expect(find.byType(ProfileSetupScreen), findsNothing);
    expect(
      find.text(lookupAppLocalizations(const Locale('ur')).errorStorage),
      findsOneWidget,
    );
  });
}

class _FailingLocaleNotifier extends LocaleNotifier {
  @override
  Locale build() => const Locale('en');

  @override
  Future<void> set(Locale locale) async {
    throw StateError('preference storage unavailable');
  }
}

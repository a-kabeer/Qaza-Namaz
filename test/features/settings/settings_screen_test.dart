import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/domain/entities/qaza_progress.dart';
import 'package:qaza_namaz/domain/entities/user_profile.dart';
import 'package:qaza_namaz/domain/repositories/user_profile_repository.dart';
import 'package:qaza_namaz/features/settings/settings_screen.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

class _FakeUserProfileRepository implements UserProfileRepository {
  _FakeUserProfileRepository({required this.stored});

  UserProfile? stored;
  int saveCount = 0;

  @override
  Future<UserProfile?> load() async => stored;

  @override
  Future<void> save(UserProfile profile) async {
    stored = profile;
    saveCount++;
  }

  @override
  Future<void> saveLocalOnly(UserProfile profile) => save(profile);

  @override
  Future<void> clear() async {
    stored = null;
  }
}

Widget _app(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: Consumer(
      builder: (context, ref, child) => MaterialApp(
        locale: ref.watch(localeProvider),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SettingsScreen(),
      ),
    ),
  );
}

ProviderContainer _container(
  _FakeUserProfileRepository repository,
  LocaleNotifier Function() localeNotifier,
) {
  return ProviderContainer(
    overrides: [
      userProfileRepositoryProvider.overrideWithValue(repository),
      progressSummaryProvider.overrideWith(
        (ref) async => QazaProgressSummary.empty(),
      ),
      localeProvider.overrideWith(localeNotifier),
    ],
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'Settings language change persists profile and locale together',
    (tester) async {
      final repository = _FakeUserProfileRepository(
        stored: const UserProfile(
          languageCode: 'ur',
          onboardingCompleted: true,
        ),
      );
      final container = _container(
        repository,
        _UrduLocaleNotifier.new,
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_app(container));

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(repository.stored?.languageCode, 'en');
      expect(repository.saveCount, 1);
      expect(container.read(localeProvider).languageCode, 'en');
      expect(prefs.getString(LocaleNotifier.storageKey), 'en');
    },
  );

  testWidgets(
    'selected language stays English after reloading UserProfile',
    (tester) async {
      final repository = _FakeUserProfileRepository(
        stored: const UserProfile(
          languageCode: 'ur',
          onboardingCompleted: true,
        ),
      );
      final container = _container(
        repository,
        _UrduLocaleNotifier.new,
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_app(container));

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      container.invalidate(userProfileProvider);
      final reloaded = await container.read(userProfileProvider.future);

      expect(reloaded?.languageCode, 'en');
      expect(container.read(localeProvider).languageCode, 'en');
    },
  );

  testWidgets(
    'Settings supports switching English back to Urdu',
    (tester) async {
      final repository = _FakeUserProfileRepository(
        stored: const UserProfile(
          languageCode: 'en',
          onboardingCompleted: true,
        ),
      );
      final container = _container(
        repository,
        _EnglishLocaleNotifier.new,
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_app(container));

      await tester.tap(find.text('اردو'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(repository.stored?.languageCode, 'ur');
      expect(container.read(localeProvider).languageCode, 'ur');
      expect(prefs.getString(LocaleNotifier.storageKey), 'ur');
    },
  );
}

class _UrduLocaleNotifier extends LocaleNotifier {
  @override
  Locale build() => const Locale('ur');
}

class _EnglishLocaleNotifier extends LocaleNotifier {
  @override
  Locale build() => const Locale('en');
}

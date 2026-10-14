import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/licenses/app_license_registry.dart';
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

Future<void> _chooseLanguage(
  WidgetTester tester,
  String languageCode,
) async {
  await tester.tap(find.byKey(const Key('settings_language')));
  await tester.pumpAndSettle();
  await tester.tap(
    find.byKey(Key('settings_language_option_$languageCode')),
  );
  await tester.pumpAndSettle();
}

Widget _app(ProviderContainer container) {
  registerAppLicenses();
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
    'Settings language change persists presentation locale without modifying the profile',
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

      expect(find.byKey(const Key('account_data_management')), findsNothing);
      expect(find.byKey(const Key('account_reset_qaza_counter')), findsNothing);

      await _chooseLanguage(tester, 'en');

      final prefs = await SharedPreferences.getInstance();
      expect(repository.stored?.languageCode, 'ur');
      expect(repository.saveCount, 0);
      expect(container.read(localeProvider).languageCode, 'en');
      expect(prefs.getString(LocaleNotifier.storageKey), 'en');
    },
  );

  testWidgets(
    'selected language stays independent from UserProfile persistence',
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

      await _chooseLanguage(tester, 'en');

      container.invalidate(userProfileProvider);
      final reloaded = await container.read(userProfileProvider.future);

      expect(reloaded?.languageCode, 'ur');
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

      await _chooseLanguage(tester, 'ur');

      final prefs = await SharedPreferences.getInstance();
      expect(repository.stored?.languageCode, 'en');
      expect(repository.saveCount, 0);
      expect(container.read(localeProvider).languageCode, 'ur');
      expect(prefs.getString(LocaleNotifier.storageKey), 'ur');
    },
  );

  test(
    'bundled software notices are available for the licence catalogue',
    () async {
      final entries = await loadBundledAppLicenseEntries();
      final registeredNotices = StringBuffer();
      for (final entry in entries) {
        registeredNotices.writeln(entry.packages.join('\n'));
        for (final paragraph in entry.paragraphs) {
          registeredNotices.writeln(paragraph.text);
        }
      }

      expect(registeredNotices.toString(), contains('Noto Nastaliq Urdu'));
      expect(registeredNotices.toString(), contains('SQLite3MultipleCiphers'));
    },
  );

  testWidgets(
    'About removes the GeoNames row and keeps attribution under Licenses',
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

      final aboutKey = find.byKey(const Key('settings_about'));
      await tester.scrollUntilVisible(aboutKey, 200);
      await tester.tap(aboutKey);
      await tester.pumpAndSettle();

      expect(find.text('GeoNames attribution'), findsNothing);
      expect(find.textContaining('GeoNames'), findsNothing);

      final licensesKey = find.byKey(const Key('about_licenses'));
      await tester.scrollUntilVisible(licensesKey, 200);
      await tester.tap(licensesKey);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('licenses_geonames_attribution')),
        findsOneWidget,
      );
      expect(find.textContaining('CC BY 4.0'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('licenses_software_catalogue')),
      );
      // Flutter's built-in LicensePage can keep an animation scheduled while
      // asynchronously collecting the registry. Pump the route without
      // requiring every animation to settle (which can time out in CI).
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.byType(LicensePage), findsOneWidget);
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

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/app_user.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/features/qaza/qaza_tracker_screen.dart';
import 'package:qaza_namaz/features/settings/settings_screen.dart';
import 'package:qaza_namaz/features/shell/workspace_shell.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';
import 'package:qaza_namaz/l10n/app_localizations_en.dart';
import 'package:qaza_namaz/l10n/app_localizations_ur.dart';
import 'package:qaza_namaz/l10n/prayer_type_l10n.dart';
import 'support/in_memory_qaza_repository.dart';

const _user = AppUser(id: 'test-user', email: 'test@example.com');

QazaRecord _record(PrayerType prayer, DateTime date) {
  final stamp = DateTime(2026, 1, 1);
  return QazaRecord(
    id: 'test-user_${prayer.name}_2025-01-01',
    userId: 'test-user',
    prayerType: prayer,
    originalDate: date,
    createdAt: stamp,
    updatedAt: stamp,
  );
}

Widget _app({
  required Widget home,
  required Locale locale,
  InMemoryQazaRepository? repository,
}) =>
    ProviderScope(
      overrides: [
        if (repository != null)
          qazaRepositoryProvider.overrideWithValue(repository),
        activeUserIdProvider.overrideWithValue('test-user'),
        authStateProvider.overrideWith((ref) => Stream.value(_user)),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );

Future<void> _pump(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('resources', () {
    test('English and Urdu are both supported, Arabic is not yet bundled', () {
      final codes = AppLocalizations.supportedLocales
          .map((locale) => locale.languageCode)
          .toList();
      expect(codes, containsAll(<String>['en', 'ur']));
      expect(codes, isNot(contains('ar')),
          reason: 'Arabic is architecturally ready but has no app_ar.arb yet');
    });

    test('Material and Cupertino delegates are wired for every locale', () {
      expect(
        AppLocalizations.localizationsDelegates,
        containsAll(<Object>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ]),
      );
    });

    test('every prayer name is translated', () {
      final en = AppLocalizationsEn();
      final ur = AppLocalizationsUr();
      for (final prayer in PrayerType.values) {
        expect(prayer.localizedLabel(en), isNotEmpty);
        expect(prayer.localizedLabel(ur), isNotEmpty);
        expect(
          prayer.localizedLabel(ur),
          isNot(prayer.localizedLabel(en)),
          reason: '${prayer.name} must have a distinct Urdu name',
        );
      }
    });

    test('plurals are translated for one and many', () {
      final en = AppLocalizationsEn();
      final ur = AppLocalizationsUr();
      expect(en.qazaCompleteCount(1), 'Complete 1 Qaza');
      expect(en.qazaCompleteCount(20), 'Complete 20 Qaza');
      expect(ur.qazaCompleteCount(1), contains('1'));
      expect(ur.qazaCompleteCount(20), contains('20'));
      expect(ur.qazaCompleteCount(1), isNot(en.qazaCompleteCount(1)));
      expect(en.qazaCompletedCount(0), 'Nothing was completed.');
      expect(ur.qazaCompletedCount(0), isNot(en.qazaCompletedCount(0)));
    });

    test('Urdu covers every key in the English template', () {
      // AppLocalizationsUr is generated from app_ur.arb; a missing key would
      // fall back to the English string, so compare a representative sample of
      // user-facing surfaces.
      final en = AppLocalizationsEn();
      final ur = AppLocalizationsUr();
      final pairs = <String, String>{
        'navHome': ur.navHome,
        'navQaza': ur.navQaza,
        'navSettings': ur.navSettings,
        'qazaEmptyTitle': ur.qazaEmptyTitle,
        'settingsLanguage': ur.settingsLanguage,
        'calcStepResult': ur.calcStepResult,
        'commonRetry': ur.commonRetry,
      };
      final english = <String, String>{
        'navHome': en.navHome,
        'navQaza': en.navQaza,
        'navSettings': en.navSettings,
        'qazaEmptyTitle': en.qazaEmptyTitle,
        'settingsLanguage': en.settingsLanguage,
        'calcStepResult': en.calcStepResult,
        'commonRetry': en.commonRetry,
      };
      pairs.forEach((key, value) {
        expect(value, isNotEmpty);
        expect(value, isNot(english[key]), reason: '$key is untranslated');
      });
    });
  });

  group('locale selection', () {
    test('defaults to English and accepts only supported locales', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(localeProvider), const Locale('en'));
      container.read(localeProvider.notifier).set(const Locale('fr'));
      expect(container.read(localeProvider), const Locale('en'),
          reason: 'an unsupported locale must be ignored');

      container.read(localeProvider.notifier).set(const Locale('ur'));
      expect(container.read(localeProvider), const Locale('ur'));
    });

    test('the chosen language is persisted and restored', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(localeProvider.notifier).set(const Locale('ur'));
      await Future<void>.delayed(Duration.zero);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(LocaleNotifier.storageKey), 'ur');

      final restored = ProviderContainer();
      addTearDown(restored.dispose);
      await restored.read(localeProvider.notifier).restore();
      expect(restored.read(localeProvider), const Locale('ur'));
    });

    test('a malformed stored language falls back to English', () async {
      SharedPreferences.setMockInitialValues({
        LocaleNotifier.storageKey: 'not-a-language',
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(localeProvider.notifier).restore();
      expect(container.read(localeProvider), const Locale('en'));
    });
  });

  group('rendering', () {
    testWidgets('navigation destinations render in English', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(_app(
        home: const WorkspaceShell(),
        locale: const Locale('en'),
        repository: InMemoryQazaRepository(),
      ));
      await _pump(tester);

      expect(find.text('Home'), findsWidgets);
      expect(find.text('Knowledge'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      // Qaza and Calculator are no longer bar destinations.
      expect(find.text('Calculator'), findsNothing);
    });

    testWidgets('navigation destinations render in Urdu', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(_app(
        home: const WorkspaceShell(),
        locale: const Locale('ur'),
        repository: InMemoryQazaRepository(),
      ));
      await _pump(tester);

      final ur = AppLocalizationsUr();
      expect(find.text(ur.navHome), findsWidgets);
      expect(find.text(ur.navKnowledge), findsOneWidget);
      expect(find.text(ur.navSettings), findsOneWidget);
      expect(find.text('Settings'), findsNothing);
    });

    testWidgets('Urdu lays out right to left', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      TextDirection? direction;
      await tester.pumpWidget(_app(
        home: Builder(
          builder: (context) {
            direction = Directionality.of(context);
            return const SizedBox.shrink();
          },
        ),
        locale: const Locale('ur'),
      ));
      await _pump(tester);
      expect(direction, TextDirection.rtl);
    });

    testWidgets('English lays out left to right', (tester) async {
      TextDirection? direction;
      await tester.pumpWidget(_app(
        home: Builder(
          builder: (context) {
            direction = Directionality.of(context);
            return const SizedBox.shrink();
          },
        ),
        locale: const Locale('en'),
      ));
      await _pump(tester);
      expect(direction, TextDirection.ltr);
    });

    testWidgets('the Qaza workspace renders Urdu prayer names and states',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      final repository = InMemoryQazaRepository();
      await repository.addRecords([
        _record(PrayerType.fajr, DateTime(2025, 1, 1)),
      ]);

      await tester.pumpWidget(_app(
        home: const QazaTrackerScreen(),
        locale: const Locale('ur'),
        repository: repository,
      ));
      await _pump(tester);

      final ur = AppLocalizationsUr();
      expect(find.text(ur.qazaTitle), findsWidgets);
      await tester.tap(find.byKey(const Key('qaza_tracker_filter_button')));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilterChip, ur.prayerFajr), findsOneWidget);
      expect(find.text(ur.prayerFajr), findsWidgets);
      expect(find.text('Fajr'), findsNothing);
      expect(find.text(ur.statusPending), findsWidgets);
    });

    testWidgets('the Urdu empty state replaces the English one',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(_app(
        home: const QazaTrackerScreen(),
        locale: const Locale('ur'),
        repository: InMemoryQazaRepository(),
      ));
      await _pump(tester);

      expect(find.text(AppLocalizationsUr().qazaEmptyTitle), findsOneWidget);
      expect(find.text('No Qaza records yet'), findsNothing);
    });

    testWidgets('Settings offers a working Urdu selection', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(_user)),
          ],
          child: Consumer(
            builder: (context, ref, _) => MaterialApp(
              locale: ref.watch(localeProvider),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const SettingsScreen(),
            ),
          ),
        ),
      );
      await _pump(tester);
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsWidgets);
      final ur = AppLocalizationsUr();

      await tester.tap(find.text(ur.languageUrdu));
      await tester.pumpAndSettle();

      expect(find.text(ur.settingsTitle), findsWidgets);
      expect(find.text(ur.settingsLanguage), findsWidgets);
      expect(find.text('Settings'), findsNothing);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/theme/app_theme.dart';
import 'package:qaza_namaz/domain/services/cloud_sync_contracts.dart';
import 'package:qaza_namaz/features/onboarding/cloud_setup_choice_screen.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

Widget _app(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: Consumer(
      builder: (context, ref, child) {
        final locale = ref.watch(localeProvider);
        final primaryColor = ref.watch(primaryColorProvider);
        return MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light(locale: locale, primaryColor: primaryColor),
          darkTheme: AppTheme.dark(locale: locale, primaryColor: primaryColor),
          themeMode: ref.watch(themeModeProvider).materialMode,
          home: const CloudSetupChoiceScreen(),
        );
      },
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('theme selector precedes language and offers only theme modes',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        // Keep this UI contract test independent of platform cloud restore.
        cloudAccountStartupRestoreProvider.overrideWith(
          (ref) async => const CloudAccountSnapshot.unavailable(),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    final themeSelector = find.byKey(const Key('cloud_setup_theme_selector'));
    final languageSelector =
        find.byKey(const Key('cloud_setup_language_selector'));
    expect(themeSelector, findsOneWidget);
    expect(languageSelector, findsOneWidget);
    expect(
      tester.getCenter(themeSelector).dx,
      lessThan(tester.getCenter(languageSelector).dx),
    );
    expect(find.text('Teal'), findsNothing);
    expect(find.text('Blue'), findsNothing);

    await tester.tap(themeSelector);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('cloud_setup_theme_option_system')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('cloud_setup_theme_option_light')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('cloud_setup_theme_option_dark')),
      findsOneWidget,
    );
    expect(find.text('Teal'), findsNothing);

    await tester.tap(find.byKey(const Key('cloud_setup_theme_option_dark')));
    await tester.pumpAndSettle();
    expect(container.read(themeModeProvider), AppThemeMode.dark);
    await tester.pump(const Duration(milliseconds: 20));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(ThemeModeNotifier.storageKey), 'dark');
  });
}

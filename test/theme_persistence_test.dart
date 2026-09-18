import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/theme/app_theme.dart';

void main() {
  test('defaults to the system theme when nothing is stored', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(themeModeProvider), AppThemeMode.system);
    await container.read(themeModeProvider.notifier).restore();
    expect(container.read(themeModeProvider), AppThemeMode.system);
  });

  test('a selected theme is written to local storage', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(themeModeProvider.notifier).set(AppThemeMode.dark);
    expect(container.read(themeModeProvider), AppThemeMode.dark);

    await Future<void>.delayed(Duration.zero);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(ThemeModeNotifier.storageKey), 'dark');
  });

  test('a stored theme is restored on startup', () async {
    SharedPreferences.setMockInitialValues({
      ThemeModeNotifier.storageKey: 'light',
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(themeModeProvider.notifier).restore();
    expect(container.read(themeModeProvider), AppThemeMode.light);
    expect(container.read(themeModeProvider).materialMode, ThemeMode.light);
  });

  test('a malformed stored value falls back to the system theme', () async {
    SharedPreferences.setMockInitialValues({
      ThemeModeNotifier.storageKey: 'not-a-theme',
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(themeModeProvider.notifier).restore();
    expect(container.read(themeModeProvider), AppThemeMode.system);
  });

  testWidgets('a restored dark theme reaches the application', (tester) async {
    SharedPreferences.setMockInitialValues({
      ThemeModeNotifier.storageKey: 'dark',
    });
    Brightness? brightness;

    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: ref.watch(themeModeProvider).materialMode,
            home: Builder(
              builder: (context) {
                brightness = Theme.of(context).brightness;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(brightness, Brightness.dark);
  });
}

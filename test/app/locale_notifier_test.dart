import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' as intl;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('selected language is persisted and restored by a new container',
      () async {
    final first = ProviderContainer();
    await first.read(localeRestorationProvider.future);
    await first.read(localeProvider.notifier).set(const Locale('ur'));

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString(LocaleNotifier.storageKey), 'ur');
    expect(first.read(localeProvider).languageCode, 'ur');

    first.dispose();
    final restarted = ProviderContainer();
    addTearDown(restarted.dispose);

    await restarted.read(localeRestorationProvider.future);
    expect(restarted.read(localeProvider).languageCode, 'ur');
  });

  test('Intl date format locale follows language selection', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(localeRestorationProvider.future);
    await container.read(localeProvider.notifier).set(const Locale('ur'));
    expect(intl.Intl.defaultLocale, 'ur');

    await container.read(localeProvider.notifier).set(const Locale('en'));
    expect(intl.Intl.defaultLocale, 'en');
  });

  test('Arabic selection is persisted and restored after restart', () async {
    final first = ProviderContainer();
    await first.read(localeRestorationProvider.future);
    await first.read(localeProvider.notifier).set(const Locale('ar'));
    expect(first.read(localeProvider).languageCode, 'ar');
    expect(intl.Intl.defaultLocale, 'ar');
    first.dispose();

    final restarted = ProviderContainer();
    addTearDown(restarted.dispose);
    await restarted.read(localeRestorationProvider.future);
    expect(restarted.read(localeProvider).languageCode, 'ar');
    expect(intl.Intl.defaultLocale, 'ar');
  });

  test('Roman Urdu script preference is persisted and restored distinctly',
      () async {
    const romanUrdu =
        Locale.fromSubtags(languageCode: 'ur', scriptCode: 'Latn');
    final first = ProviderContainer();
    await first.read(localeRestorationProvider.future);
    await first.read(localeProvider.notifier).set(romanUrdu);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString(LocaleNotifier.storageKey), 'ur_Latn');
    expect(first.read(localeProvider).scriptCode, 'Latn');
    expect(intl.Intl.defaultLocale, 'ur_Latn');
    first.dispose();

    final restarted = ProviderContainer();
    addTearDown(restarted.dispose);
    await restarted.read(localeRestorationProvider.future);
    expect(restarted.read(localeProvider).languageCode, 'ur');
    expect(restarted.read(localeProvider).scriptCode, 'Latn');
    expect(intl.Intl.defaultLocale, 'ur_Latn');

    SharedPreferences.setMockInitialValues({'language_code': 'ur'});
    final legacy = ProviderContainer();
    addTearDown(legacy.dispose);
    await legacy.read(localeRestorationProvider.future);
    expect(legacy.read(localeProvider).scriptCode, isNull);
  });

  test('unsupported saved language preserves a supported fallback', () async {
    SharedPreferences.setMockInitialValues({'language_code': 'fr'});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(localeRestorationProvider.future);

    expect(
      AppLocalizations.supportedLocales
          .map((locale) => locale.languageCode)
          .contains(container.read(localeProvider).languageCode),
      isTrue,
    );
  });
}

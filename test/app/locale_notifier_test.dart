import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

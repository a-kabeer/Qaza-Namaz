import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/core/widgets/language_selector.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

void main() {
  const options = <LanguageOption<String>>[
    LanguageOption<String>(value: 'en', languageCode: 'en'),
    LanguageOption<String>(value: 'ur', languageCode: 'ur'),
    LanguageOption<String>(value: 'ar', languageCode: 'ar'),
  ];

  test('native language catalogue has a safe fallback', () {
    expect(NativeLanguageNames.forCode('en'), 'English');
    expect(NativeLanguageNames.forCode('ur'), 'اردو');
    expect(NativeLanguageNames.forCode('ar'), 'العربية');
    expect(NativeLanguageNames.forCode('xx'), 'xx');
  });

  test('application options use only supported locales and native labels', () {
    final options = AppLocalizations.supportedLocales
        .map(
          (locale) => LanguageOption<Locale>(
            value: locale,
            languageCode: locale.languageCode,
          ),
        )
        .toList(growable: false);

    expect(options.map((option) => option.languageCode), ['ar', 'en', 'ur']);
    expect(
      options.map((option) => option.displayName),
      ['العربية', 'English', 'اردو'],
    );
  });

  testWidgets('renders native names and reports the selected value',
      (tester) async {
    var selected = 'en';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: StatefulBuilder(
              builder: (context, setState) => LanguageSelector<String>(
                key: const Key('language_selector'),
                options: options,
                value: selected,
                optionKeyPrefix: 'language_option',
                semanticLabel: 'Application language',
                onChanged: (next) => setState(() => selected = next),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('English'), findsOneWidget);
    await tester.tap(find.byKey(const Key('language_selector')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('language_option_ur')), findsOneWidget);
    expect(find.byKey(const Key('language_option_ar')), findsOneWidget);
    await tester.tap(find.byKey(const Key('language_option_ar')));
    await tester.pumpAndSettle();

    expect(selected, 'ar');
    expect(find.text('العربية'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fits many language options in a narrow RTL viewport',
      (tester) async {
    const expandedOptions = <LanguageOption<String>>[
      LanguageOption<String>(value: 'en', languageCode: 'en'),
      LanguageOption<String>(value: 'ur', languageCode: 'ur'),
      LanguageOption<String>(value: 'ar', languageCode: 'ar'),
      LanguageOption<String>(value: 'bn', languageCode: 'bn'),
      LanguageOption<String>(value: 'de', languageCode: 'de'),
      LanguageOption<String>(value: 'es', languageCode: 'es'),
      LanguageOption<String>(value: 'fa', languageCode: 'fa'),
      LanguageOption<String>(value: 'fr', languageCode: 'fr'),
      LanguageOption<String>(value: 'id', languageCode: 'id'),
      LanguageOption<String>(value: 'ms', languageCode: 'ms'),
      LanguageOption<String>(value: 'tr', languageCode: 'tr'),
      LanguageOption<String>(value: 'zh', languageCode: 'zh'),
    ];

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 720);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const LanguageSelector<String>(
                  key: Key('compact_language_selector'),
                  options: expandedOptions,
                  value: 'ar',
                  optionKeyPrefix: 'compact_option',
                  layout: LanguageSelectorLayout.compact,
                  semanticLabel: 'Knowledge language',
                  onChanged: _ignoreString,
                ),
                const SizedBox(height: 16),
                const LanguageSelector<String>(
                  key: Key('full_language_selector'),
                  options: expandedOptions,
                  value: 'ur',
                  optionKeyPrefix: 'full_option',
                  layout: LanguageSelectorLayout.fullWidth,
                  semanticLabel: 'Application language',
                  onChanged: _ignoreString,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('compact_language_selector')), findsOneWidget);
    expect(find.byKey(const Key('full_language_selector')), findsOneWidget);
    await tester.tap(find.byKey(const Key('compact_language_selector')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('compact_option_ar')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _ignoreString(String _) {}

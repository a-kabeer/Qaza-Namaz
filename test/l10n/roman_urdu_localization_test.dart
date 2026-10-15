import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/core/theme/app_theme.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';
import 'package:qaza_namaz/l10n/roman_urdu_widgets_localizations.dart';

const romanUrduLocale =
    Locale.fromSubtags(languageCode: 'ur', scriptCode: 'Latn');

void main() {
  test('Roman Urdu is a distinct supported locale with Latin UI strings', () {
    expect(AppLocalizations.supportedLocales, contains(romanUrduLocale));

    final l10n = lookupAppLocalizations(romanUrduLocale);
    expect(l10n.localeName, 'ur_Latn');
    expect(l10n.appTitle, 'Qaza Namaz');
    expect(l10n.navHome, 'Home');
    expect(l10n.navQaza, 'Qaza');
    expect(l10n.navKnowledge, 'Rehnumai');
    expect(l10n.prayerFajr, 'Fajr');
    expect(l10n.commonContinue, 'Jari rakhein');
    expect(l10n.navPrayerTime, 'Auqat');
    expect(l10n.prayerTimeTitle, 'Namaz ke auqat');

    // Keep the compact Roman Urdu navigation label isolated to ur_Latn.
    expect(
      lookupAppLocalizations(const Locale('en')).navPrayerTime,
      'Prayer Time',
    );
    expect(
      lookupAppLocalizations(const Locale('ur')).navPrayerTime,
      'نماز کے اوقات',
    );

    final arabicScript = RegExp(r'[\u0600-\u06FF]');
    for (final value in [
      l10n.appTitle,
      l10n.navHome,
      l10n.navQaza,
      l10n.navKnowledge,
      l10n.prayerFajr,
      l10n.commonContinue,
    ]) {
      expect(value, isNot(matches(arabicScript)));
    }
  });

  test('Roman Urdu ARB standalone text follows sentence case', () {
    final arb = jsonDecode(
      File('lib/l10n/app_ur_Latn.arb').readAsStringSync(),
    ) as Map<String, dynamic>;

    for (final entry in arb.entries) {
      if (entry.key.startsWith('@') || entry.value is! String) continue;
      final value = entry.value as String;
      expect(value, isNot(matches(RegExp(r'^[a-z]'))), reason: entry.key);
      expect(
        value,
        isNot(matches(RegExp(r'[.!?]\s+[a-z]'))),
        reason: entry.key,
      );
      expect(value, isNot(matches(RegExp(r'\n[a-z]'))), reason: entry.key);
      expect(
        value,
        isNot(
          matches(RegExp(r'(?:=\d+|other|one|zero|few|many)\{[a-z]')),
        ),
        reason: entry.key,
      );
    }
  });

  test('Roman Urdu uses Latin typography in both themes', () {
    expect(AppTheme.isUrdu(romanUrduLocale), isFalse);
    expect(
      AppTheme.light(locale: romanUrduLocale).textTheme.bodyMedium?.fontFamily,
      'Manrope',
    );
    expect(
      AppTheme.dark(locale: romanUrduLocale).textTheme.bodyMedium?.fontFamily,
      'Manrope',
    );
  });

  testWidgets(
      'Roman Urdu Prayer Time navigation label fits on one line at 320px',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final l10n = lookupAppLocalizations(romanUrduLocale);
    await tester.pumpWidget(
      MaterialApp(
        locale: romanUrduLocale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: <LocalizationsDelegate<dynamic>>[
          const RomanUrduWidgetsLocalizationsDelegate(),
          ...AppLocalizations.localizationsDelegates,
        ],
        home: Scaffold(
          bottomNavigationBar: NavigationBar(
            destinations: <NavigationDestination>[
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                label: l10n.navHome,
              ),
              NavigationDestination(
                icon: const Icon(Icons.checklist_outlined),
                label: l10n.navQaza,
              ),
              NavigationDestination(
                icon: const Icon(Icons.schedule_outlined),
                label: l10n.navPrayerTime,
              ),
              NavigationDestination(
                icon: const Icon(Icons.menu_book_outlined),
                label: l10n.navKnowledge,
              ),
              NavigationDestination(
                icon: const Icon(Icons.tune_outlined),
                label: l10n.navSettings,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Auqat'), findsOneWidget);
    final labelParagraph =
        tester.renderObject<RenderParagraph>(find.text('Auqat'));
    final labelPainter = TextPainter(
      text: labelParagraph.text,
      textDirection: labelParagraph.textDirection,
      maxLines: labelParagraph.maxLines,
    )..layout(maxWidth: labelParagraph.size.width);
    expect(
      labelPainter.computeLineMetrics(),
      hasLength(1),
      reason: 'The compact Prayer Time navigation label must render on one line.',
    );
    labelPainter.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Roman Urdu resolves to left-to-right layout', (tester) async {
    TextDirection? direction;
    await tester.pumpWidget(
      MaterialApp(
        locale: romanUrduLocale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: <LocalizationsDelegate<dynamic>>[
          const RomanUrduWidgetsLocalizationsDelegate(),
          ...AppLocalizations.localizationsDelegates,
        ],
        home: Builder(
          builder: (context) {
            direction = Directionality.of(context);
            return Text(AppLocalizations.of(context).navHome);
          },
        ),
      ),
    );

    expect(direction, TextDirection.ltr);
    expect(find.text('Home'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

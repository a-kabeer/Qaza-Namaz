import 'package:flutter/material.dart';
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
    expect(l10n.appTitle, 'Qaza Namaz');
    expect(l10n.navHome, 'Home');
    expect(l10n.navQaza, 'Qaza');
    expect(l10n.navKnowledge, 'Rehnumai');
    expect(l10n.prayerFajr, 'Fajr');
    expect(l10n.commonContinue, 'jari rakhein');

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

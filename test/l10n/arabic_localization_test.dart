import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/core/theme/app_theme.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

void main() {
  test('Arabic is registered and returns localized prayer labels', () {
    expect(
      AppLocalizations.supportedLocales.map((locale) => locale.languageCode),
      contains('ar'),
    );
    final l10n = lookupAppLocalizations(const Locale('ar'));
    expect(l10n.navHome, 'الرئيسية');
    expect(l10n.prayerFajr, 'الفجر');
    expect(l10n.homeDailyProgress(1, 5), 'تم إكمال 1 من أصل 5');
    expect(l10n.qazaCompletedCount(0), 'لم يتم إكمال أي قضاء.');
  });

  test('Arabic uses Noto Sans Arabic and Urdu keeps Nastaliq', () {
    final arabicTheme = AppTheme.light(locale: const Locale('ar'));
    final darkArabicTheme = AppTheme.dark(locale: const Locale('ar'));
    final urduTheme = AppTheme.light(locale: const Locale('ur'));
    expect(arabicTheme.textTheme.bodyMedium?.fontFamily, 'Noto Sans Arabic');
    expect(
        darkArabicTheme.textTheme.bodyMedium?.fontFamily, 'Noto Sans Arabic');
    expect(urduTheme.textTheme.bodyMedium?.fontFamily, AppTheme.urduFamily);
  });

  testWidgets('Arabic locale lays out the app right-to-left', (tester) async {
    TextDirection? direction;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            direction = Directionality.of(context);
            return Text(AppLocalizations.of(context).navHome);
          },
        ),
      ),
    );
    expect(direction, TextDirection.rtl);
    expect(find.text('الرئيسية'), findsOneWidget);
  });
}

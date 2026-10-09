import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

void main() {
  group('Import review localization', () {
    for (final locale in const <Locale>[Locale('en'), Locale('ur')]) {
      test('${locale.languageCode} summary uses real paragraph breaks', () async {
        final l10n = await AppLocalizations.delegate.load(locale);
        final summary = l10n.dataImportRestoreSummary(
          2160,
          1,
          14,
          l10n.dataImportOnboardingComplete,
        );

        expect(summary, contains('\n\n'));
        expect(summary, isNot(contains(r'\n')));
      });
    }
  });
}

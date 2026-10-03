import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/l10n/app_localizations_en.dart';
import 'package:qaza_namaz/l10n/app_localizations_ur.dart';

void main() {
  test('profile Qaza success localization resolves numeric interpolation', () {
    final en = AppLocalizationsEn();
    final ur = AppLocalizationsUr();

    final enMessage = en.profileQazaUpdatedCounts(120, 30);
    final urMessage = ur.profileQazaUpdatedCounts(120, 30);

    expect(enMessage, contains('120'));
    expect(enMessage, contains('30'));
    expect(urMessage, contains('120'));
    expect(urMessage, contains('30'));

    for (final message in [enMessage, urMessage]) {
      expect(message, isNot(contains(r'${')));
      expect(message, isNot(contains(r'{')));
      expect(message, isNot(contains(r'}')));
    }
  });
}

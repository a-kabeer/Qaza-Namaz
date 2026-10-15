import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Keeps Flutter widget direction LTR for Urdu written in Latin script.
/// Other Urdu locales continue to use Flutter's standard RTL delegate.
class RomanUrduWidgetsLocalizations extends DefaultWidgetsLocalizations {
  const RomanUrduWidgetsLocalizations();

  @override
  TextDirection get textDirection => TextDirection.ltr;
}

/// Overrides only widget direction for the `ur-Latn` locale.
class RomanUrduWidgetsLocalizationsDelegate
    extends LocalizationsDelegate<WidgetsLocalizations> {
  const RomanUrduWidgetsLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'ur' && locale.scriptCode?.toLowerCase() == 'latn';

  @override
  Future<WidgetsLocalizations> load(Locale locale) =>
      SynchronousFuture<WidgetsLocalizations>(
        const RomanUrduWidgetsLocalizations(),
      );

  @override
  bool shouldReload(RomanUrduWidgetsLocalizationsDelegate old) => false;
}

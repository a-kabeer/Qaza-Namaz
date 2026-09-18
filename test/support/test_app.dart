import 'package:flutter/material.dart';

import 'package:qaza_namaz/l10n/app_localizations.dart';

/// A `MaterialApp` configured the way production configures it.
///
/// Screens resolve their strings through `AppLocalizations.of(context)`, so a
/// test host has to supply the same delegates the real app does. Using this
/// instead of a bare `MaterialApp` keeps tests honest about that requirement
/// while staying const-constructible.
class TestApp extends StatelessWidget {
  const TestApp({
    super.key,
    required this.home,
    this.theme,
    this.darkTheme,
    this.themeMode,
    this.locale,
    this.builder,
  });

  final Widget home;
  final ThemeData? theme;
  final ThemeData? darkTheme;
  final ThemeMode? themeMode;
  final Locale? locale;

  /// Wraps the navigator, for tests that need to alter `MediaQuery` — text
  /// scaling, for instance.
  final TransitionBuilder? builder;

  @override
  Widget build(BuildContext context) => MaterialApp(
        theme: theme,
        darkTheme: darkTheme,
        themeMode: themeMode ?? ThemeMode.system,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: builder,
        home: home,
      );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/auth_gate.dart';
import '../l10n/app_localizations.dart';

/// Root widget for the application shell.
///
/// Locale and theme both come from persisted Riverpod state. Text direction is
/// not set here: Flutter derives it from the active locale, so Urdu renders
/// right to left without any per-widget handling.
class QazaNamazApp extends ConsumerWidget {
  const QazaNamazApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider).materialMode,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AuthGate(),
    );
  }
}

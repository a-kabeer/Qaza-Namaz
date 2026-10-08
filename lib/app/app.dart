import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../core/time/local_date_service.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/app_snackbar.dart';
import '../features/onboarding/startup_gate.dart';
import '../l10n/app_localizations.dart';
import 'providers.dart';

class QazaNamazApp extends ConsumerStatefulWidget {
  const QazaNamazApp({super.key});

  @override
  ConsumerState<QazaNamazApp> createState() => _QazaNamazAppState();
}

class _QazaNamazAppState extends ConsumerState<QazaNamazApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(ref.read(accountSessionManagerProvider.notifier).initialize());
    unawaited(_configureLocalTimezone());
  }

  Future<void> _configureLocalTimezone() async {
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      LocalDateService.configureLocalTimezone(timezone.identifier);
    } catch (_) {
      // Local timezone is useful runtime state but does not gate local startup.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(locale: locale),
      darkTheme: AppTheme.dark(locale: locale),
      themeMode: ref.watch(themeModeProvider).materialMode,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => AppScaffoldMessenger(
        key: appScaffoldMessengerKey,
        child: child!,
      ),
      home: const StartupGate(),
    );
  }
}

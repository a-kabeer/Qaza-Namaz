import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/auth_gate.dart';
import '../features/settings/app_lock_controller.dart';
import '../features/notifications/notification_controller.dart';
import '../l10n/app_localizations.dart';
import 'providers.dart';
import 'startup_gate.dart';

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
    unawaited(_initializeNotifications());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref.read(appLockControllerProvider.notifier).onLifecycleState(state);
  }

  Future<void> _initializeNotifications() async {
    try {
      await ref.read(notificationSchedulerProvider).initialize();
    } catch (error, stack) {
      if (kDebugMode) {
        debugPrint(
          '[notifications] app-start initialization failed: '
          '${error.runtimeType}: $error',
        );
        debugPrintStack(stackTrace: stack);
      }
    }
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
      home: const StartupGate(child: AuthGate()),
    );
  }
}

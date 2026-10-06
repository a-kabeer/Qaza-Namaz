import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../core/time/local_date_service.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/app_snackbar.dart';
import '../features/onboarding/startup_gate.dart';
import '../data/remote/firebase_backup_scheduler.dart';
import '../l10n/app_localizations.dart';
import 'providers.dart';

class QazaNamazApp extends ConsumerStatefulWidget {
  const QazaNamazApp({super.key});

  @override
  ConsumerState<QazaNamazApp> createState() => _QazaNamazAppState();
}

class _QazaNamazAppState extends ConsumerState<QazaNamazApp>
    with WidgetsBindingObserver {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _appVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(
      ref.read(accountSessionManagerProvider.notifier).initialize(),
    );
    // Persistent scheduling is a safety net for the existing outbox worker.
    // It does not own sync state and never bypasses account/auth/App Check checks.
    unawaited(FirebaseBackupScheduler.initialize());
    unawaited(_configureLocalTimezone());
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((_) {
      if (mounted && !_appVisible) {
        ref.read(backupWorkerProvider).runOnce();
      }
    });
  }

  Future<void> _configureLocalTimezone() async {
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      LocalDateService.configureLocalTimezone(timezone.identifier);
    } catch (_) {
      // Timezone configuration is useful runtime state but is not required
      // to determine the first safe account/routing screen.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _appVisible = true;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _appVisible = false;
        if (state == AppLifecycleState.paused && mounted) {
          // Backups are deliberately moved out of the foreground so a local
          // Qaza completion never competes with Firestore work for frame time.
          ref.read(backupWorkerProvider).runOnce();
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
      builder: (context, child) => AppScaffoldMessenger(
        key: appScaffoldMessengerKey,
        child: child!,
      ),
      home: const StartupGate(),
    );
  }
}

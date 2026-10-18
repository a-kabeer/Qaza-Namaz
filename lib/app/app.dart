import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../core/diagnostics/diagnostics.dart';
import '../core/time/local_date_service.dart';
import '../features/calendar/calendar_controller.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/app_snackbar.dart';
import '../features/account/account_screen.dart';
import '../features/onboarding/startup_gate.dart';
import '../l10n/app_localizations.dart';
import '../l10n/roman_urdu_widgets_localizations.dart';
import 'providers.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

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
    } finally {
      // The first read may happen before native timezone discovery completes.
      // Re-evaluate the cached date provider after startup and on every resume.
      if (mounted) ref.invalidate(calendarTodayProvider);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(_refreshLocalDateEnvironment());
  }

  Future<void> _refreshLocalDateEnvironment() async {
    await _configureLocalTimezone();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final assetPackage = ref.watch(packageAssetNamespaceProvider);
    final primaryColor = ref.watch(primaryColorProvider);
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(
        locale: locale,
        assetPackage: assetPackage,
        primaryColor: primaryColor,
      ),
      darkTheme: AppTheme.dark(
        locale: locale,
        assetPackage: assetPackage,
        primaryColor: primaryColor,
      ),
      themeMode: ref.watch(themeModeProvider).materialMode,
      locale: locale,
      localizationsDelegates: <LocalizationsDelegate<dynamic>>[
        const RomanUrduWidgetsLocalizationsDelegate(),
        ...AppLocalizations.localizationsDelegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => AppScaffoldMessenger(
        key: appScaffoldMessengerKey,
        child: _GuestGooglePromptHost(child: child!),
      ),
      home: const StartupGate(),
    );
  }
}

class _GuestGooglePromptHost extends ConsumerStatefulWidget {
  const _GuestGooglePromptHost({required this.child});

  final Widget child;

  @override
  ConsumerState<_GuestGooglePromptHost> createState() =>
      _GuestGooglePromptHostState();
}

class _GuestGooglePromptHostState
    extends ConsumerState<_GuestGooglePromptHost> {
  bool _showingPrompt = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(guestConnectPromptRequestProvider, (previous, next) {
      if (next > (previous ?? 0)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(_showGuestPrompt());
        });
      }
    });
    return widget.child;
  }

  Future<void> _showGuestPrompt() async {
    if (!mounted || _showingPrompt) return;
    final navigator = appNavigatorKey.currentState;
    final navigatorContext = navigator?.overlay?.context;
    if (navigator == null || navigatorContext == null || !navigator.mounted) {
      return;
    }
    _showingPrompt = true;
    try {
      final l10n = AppLocalizations.of(navigatorContext);
      final dialogResult = showDialog<bool>(
        context: navigatorContext,
        useRootNavigator: true,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.guestGooglePromptTitle),
          content: Text(l10n.guestGooglePromptMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.cloudSetupUseGoogle),
            ),
          ],
        ),
      );

      try {
        await ref.read(appDatabaseProvider).markGuestGooglePromptShown();
      } catch (error, stack) {
        ref.read(diagnosticsProvider).recordFailure(
              DiagnosticArea.uncaught,
              'guest_google_prompt_persist_failed',
              error,
              stack: stack,
            );
      }

      final connect = await dialogResult;
      if (connect == true && mounted && navigator.mounted) {
        await navigator.push<void>(
          MaterialPageRoute<void>(
            builder: (_) => const AccountScreen(autoConnect: true),
          ),
        );
      }
    } catch (error, stack) {
      ref.read(diagnosticsProvider).recordFailure(
            DiagnosticArea.uncaught,
            'guest_google_prompt_presentation_failed',
            error,
            stack: stack,
          );
    } finally {
      _showingPrompt = false;
    }
  }
}
